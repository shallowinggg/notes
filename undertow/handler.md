Undertow Handler Authors Guide
This guide provides an overview of how to write native handlers for Undertow. It does not cover every API method on the HttpServerExchange object, as many of them are self explanatory or covered by the javadoc. Instead this guide focuses on the concepts you will need to write an Undertow handler.

Lets start with a simple example:

import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;

public class HelloWorldServer {

    public static void main(final String[] args) {
        Undertow server = Undertow.builder()                                                    //Undertow builder
                .addHttpListener(8080, "localhost")                                             //Listener binding
                .setHandler(new HttpHandler() {                                                 //Default Handler
                    @Override
                    public void handleRequest(final HttpServerExchange exchange) throws Exception {
                        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain");  //Response Headers
                        exchange.getResponseSender().send("Hello World");                       //Response Sender
                    }
                }).build();
        server.start();
    }

}
For the most part this is all fairly self explanatory:

The Undertow Builder
This API enables you to quickly configure and launch an Undertow server. It is intended for use in embedded and testing environments. At this stage the API is still subject to change.

Listener Binding
The next line tells the Undertow server to bind to localhost on port 8080.

Default Handler
This is the handler that will be matched if a URL does not match any of the paths that are registered with Undertow. In this case we do not have any other handlers registered, so this handler is always invoked.

Response Headers
This sets the content type header, which is fairly self explanatory. One thing to note is that Undertow does not use String as the key for the header map, but rather a case insensitive string io.undertow.util.HttpString. The io.undertow.util.Headers class contains predefined constants for all common headers.

Response Sender
The Undertow sender API is just one way of sending a response. The sender will be covered in more detail later, but in this case as no completion callback has been specified the sender knows that the provided string is the complete response, and as such will set a content length header for us and close the response when done.

From now on our code examples will focus on the handlers themselves, and not on the code to setup a server.

Request Lifecycle
(This is also covered in the Request Lifecycle document.)

When a client connects to the server Undertow creates a io.undertow.server.HttpServerConnection. When the client sends a request it is parsed by the Undertow parser, and then the resulting io.undertow.server.HttpServerExchange is passed to the root handler. When the root handler finishes one of 4 things can happen:

The exchange can be already completed
An exchange is considered complete if both request and response channels have been fully read/written. For requests with no content (such as GET and HEAD) the request side is automatically considered fully read. The read side is considered complete when a handler has written out the full response and closed and fully flushed the response channel. If an exchange is already complete then no action is taken, as the exchange is finished.

The root handler returns normally without completing the exchange
In this case the exchange will be completed by calling HttpServerExchange.endExchange(). The semantics of endExchange() are discussed later.

The root handler returns with an Exception
In this case a response code of 500 will be set, and the exchange will be ended using HttpServerExchange.endExchange().

The root handler can return after HttpServerExchange.dispatch() has been called, or after async IO has been started
In this case the dispatched task will be submitted to the dispatch executor, or if async IO has been started on either the request or response channels then this will be started. In this case the exchange will not be finished, it is up to your async task to finish the exchange when it is done processing.

By far the most common use of HttpServerExchange.dispatch() is to move execution from an IO thread where blocking is not allowed into a worker thread, which does allow for blocking operations. This pattern generally looks like:

Dispatching to a worker thread
public void handleRequest(final HttpServerExchange exchange) throws Exception {
    if (exchange.isInIoThread()) {
      exchange.dispatch(this);
      return;
    }
    //handler code
}
Because exchange is not actually dispatched until the call stack returns you can be sure that more that one thread is never active in an exchange at once. The exchange is not thread safe, however it can be passed between multiple threads as long as both threads do not attempt to modify it at once, and there is a happens before action (such as a thread pool dispatch) in between the first and second thread access.

Ending the exchange
As mentioned above, and exchange is considered done once both the request and response channels have been closed and flushed.

There are two ways to end an exchange, either by fully reading the request channel, and calling shutdownWrites() on the response channel and then flushing it, or by calling HttpServerExchange.endExchange(). When endExchange() is called Undertow will check if and content has been generated yet, if it has then it will simply drain the request channel, and close and flush the response channel. If not and there are any default response listeners registered on the exchange then Undertow will give each of them a chance to generate a default response. This mechanism is how default error pages are generated.

The Undertow Buffer Pool
As Undertow is based on NIO it uses java.nio.ByteBuffer whenever buffering is needed. These buffers are pooled, and should not be allocated on demand as this will severely impact performance. The buffer pool can be obtained by calling HttpServerConnection.getBufferPool().

Pooled buffers must be freed after use, as they will not be cleaned up by the garbage collector. The size of the buffers in the pool is configured when the server is created. Empirical testing has shown that if direct buffers are being used 16kb buffers are optimal if maximum performance is required (as this corresponds to the default socket buffer size on Linux).

Non-blocking IO
By default Undertow uses non-blocking XNIO channels, and requests initially start off in an XNIO IO thread. These channels can be used directly to send and receive data. These channels are quite low level however, so to that end, Undertow provides some abstractions to make using them a little bit easier.

The easiest way to send a response using non-blocking IO is to use the sender API as shown above. It contains several versions of the send() method for both byte and String data. Some versions of the method take a callback that is invoked when the send is complete, other versions do not take a callback and instead end the exchange when the send is complete.

Note that the sender API does not support queuing, you may not call send() again until after the callback has been notified.

When using versions of the send() method that do not take a callback the Content-Length header will be automatically set, otherwise you must set this yourself to avoid using chunked encoding.

The sender API also supports blocking IO, if the exchange has been put into blocking mode by invoking HttpServerExchange.startBlocking() then the Sender will send its data using the exchanges output stream.

Blocking IO
Undertow provides full support for blocking IO. It is not advisable to use blocking IO in an XNIO worker thread, so you will need to make sure that the request has been dispatched to a worker thread pool before attempting to read or write.

The code to dispatch to a worker thread can be found above.

To begin blocking IO call HttpServerExchange.startBlocking(). There are two versions of this method, the one which does not take any parameters which will use Undertow’s default stream implementations, and HttpServerExchange.startBlocking(BlockingHttpServerExchange blockingExchange) which allows you to customize the streams that are in use. For example the servlet implementation uses the second method to replace Undertow’s default streams with Servlet(Input/Output)Stream implementations.

Once the exchange has been put into blocking mode you can now call HttpServerExchange.getInputStream() and HttpServerExchange.getOutputStream(), and write data to them as normal. You can also still use the sender API described above, however in this case the sender implementation will use blocking IO.

By default Undertow uses buffering streams, using buffers taken from the buffer pool. If a response is small enough to fit in the buffer then a Content-Length header will automatically be set.

Headers
Request and response headers are accessible through the HttpServerExchange.getRequestHeaders() and HttpServerExchange.getResponseHeaders() methods. These methods return a HeaderMap, an optimised map implementation.

Headers are written out with the HTTP response header when the first data is written to the underlying channel (this may not be the same time as the first time data is written if buffering is used).

If you wish to force the headers to be written you can call the flush() method on either the response channel or stream.

HTTP Upgrade
In order to perform a HTTP upgrade you can call HttpServerExchange.upgradeChannel(ExchangeCompletionListener upgradeCompleteListener), the response code will be set to 101, and once the exchange is complete your listener will be notified. Your handler is responsible for setting any appropriate headers that the upgrade client will be expecting.

Last updated 2020-05-04 04:07:34 BRT