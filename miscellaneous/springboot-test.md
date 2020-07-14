# SpringBoot Test

在日常的编码工作中，测试理应是一个较为重要的组成部分。通过测试可以极大减少一些粗心导致的小错误，加快迭代的速度。同时，良好的应用`TDD`模式也可以帮助我们理清编码的细节。

## SpringMVC

引入`spring-boot-starter-test`依赖。如果你只使用`JUnit 5`，那么可以将`junit-vintage-engine`依赖排除掉，此依赖的作用为兼容`JUnit 4`。

```xml
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
            <exclusions>
                <exclusion>
                    <groupId>org.junit.vintage</groupId>
                    <artifactId>junit-vintage-engine</artifactId>
                </exclusion>
            </exclusions>
        </dependency>
```

编写一个测试`Controller`类，如下所示：

```java
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * @author shallowinggg
 */
@Controller
public class DemoController {

    @GetMapping("/get")
    @ResponseBody
    public String get(@RequestParam("id") int id) {
        return "Hello " + id;
    }
}
```

通过`Spring Test`提供的`Mock`类即可对其进行测试，如下所示：

```java
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

@SpringBootTest
@AutoConfigureMockMvc
public class DemoControllerITest {

    @Autowired
    MockMvc mockMvc;

    @Test
    public void testGet() throws Exception {
        mockMvc.perform(get("/get").param("id", "1"))
                .andDo(print())
                .andExpect(content().string("Hello 1"));
    }
}
```

`perform`方法按照你预定的想法发出一个请求，可查看`MockMvcRequestBuilders`类获取更多信息。同时，你可以通过`andDo`方法将请求以及回复的具体信息打印出来，可查看`MockMvcResultHandlers`类获取更多信息。`andExpect`方法用于判断返回信息是否与预想的相同，可查看`MockMvcResultMatchers`类获取更多信息。

`print()`方法会打印出下面的信息：

```
MockHttpServletRequest:
      HTTP Method = GET
      Request URI = /get
       Parameters = {id=[1]}
          Headers = []
             Body = null
    Session Attrs = {}

Handler:
             Type = org.example.springboot.controller.DemoController
           Method = org.example.springboot.controller.DemoController#get(int)

Async:
    Async started = false
     Async result = null

Resolved Exception:
             Type = null

ModelAndView:
        View name = null
             View = null
            Model = null

FlashMap:
       Attributes = null

MockHttpServletResponse:
           Status = 200
    Error message = null
          Headers = [Content-Type:"text/plain;charset=UTF-8", Content-Length:"7"]
     Content type = text/plain;charset=UTF-8
             Body = Hello 1
    Forwarded URL = null
   Redirected URL = null
          Cookies = []
```


使用`@SpringBootTest`会加载一个完整的容器，如果只想对`DemoController`进行单元测试，那么这无疑会增大许多无用的开销，因此它较为适合完整的集成测试。

通过下面这种方式即可只将`DemoController`加载到容器中进行测试：

```java
@WebMvcTest(DemoController.class)
public class DemoControllerTest { }
```

但是，通常我们的`Controller`类中都会依赖一些其他组件，当使用`@SpringBootTest`注解时它们会一起被加载到容器中，但是只对`DemoController`进行单元测试时，则会出现找不到bean的问题。因此，我们需要mock这些组件。

一个完整的例子如下所示：

```java
public interface DemoService {

    String foo(int arg);
}

@Controller
public class DemoController {

    private final DemoService demoService;

    @Autowired
    public DemoController(DemoService demoService) {
        this.demoService = demoService;
    }

    @GetMapping("/get")
    @ResponseBody
    public String get(@RequestParam("id") int id) {
        return demoService.foo(id);
    }
}

@WebMvcTest(DemoController.class)
public class DemoControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockBean
    DemoService demoService;

    @Test
    public void testGet() throws Exception {
        BDDMockito.given(demoService.foo(1)).willReturn("Hello 10");

        mockMvc.perform(get("/get").param("id", "1"))
                .andDo(print())
                .andExpect(content().string("Hello 10"));
    }
}

```

## Mybatis

同样，当我们对数据访问层进行单元测试时，也不愿意加载完整的容器，通常这会产生极大的时间开销，导致开发者对单元测试的痛苦。

`Mybatis`也基于`spring-boot-stater-test`实现了自己的测试套件，可以方便的对数据访问对象进行单元测试。

引入如下依赖：

```xml
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter-test</artifactId>
            <version>${mybatis-boot.version}</version>
            <scope>test</scope>
        </dependency>
```

下面展示一个完整的例子：

```java
public class User {
    private String id;

    private String name;

    // getters / setters
}

@Mapper
public interface DemoDao {

    /**
     * Find {@link User} from table 'user' by id.
     *
     * @param id query condition
     * @return User
     */
    @Select("select id, name from user where id = #{id}")
    User getUser(@Param("id") String id);
}


@MybatisTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
public class DemoDaoTest {

    @Autowired
    DemoDao demoDao;

    @Test
    public void testGetUser() {
        User user = demoDao.getUser("1");
    }
}
```

在单元测试类上加上`@MybatisTest`即可，此时会默认选用一个嵌入式数据库来进行测试，而无需连接到真实的数据库环境中。同时，你需要配置测试环境的`application.properties`或者`application.yml`文件，使用嵌入式数据库配置`dataSource`。如果你想要使用真实的数据库，请像上面的例子一样加入`@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)`注解。