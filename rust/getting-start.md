# 安装

# 使用

## vscode

插件：
* rust
* rust-analyzer
* crates
* codeLLDB
* Even Better TOML

## simple run

```shell
#!/bin/sh

file=$1
if [ -z $file ] || ! [[ $file =~ .+rs$ ]]
then
  echo "error: invalid input file"
  exit -1
fi

exec=${file%.rs}
`rustc $file` && `./$exec`
```

# cargo
* cargo new project
* cargo init
* cargo build
* cargo build --release
* cargo update
* cargo run
* cargo check

cargo使用语义版本号，例如引入依赖 `rand = '0.8.3'` 相当于 `rand = '^0.8.3'` 。

执行 `cargo update` 时会查找 `0.8.x` 序列中最新的版本以保证兼容。如果想要升级为更高的版本，需要手动在 `Cargo.toml` 中修改版本号，例如 `rand = '0.9.0'` 。

# variable
* 通过let定义，例如`let a = 1; `
* 默认类型推导，可以明确指定类型 `let a: i32 = 1; `
* 默认不可变，可以指定为可变 `let mut a = 1; `
* 常量定义必须要携带类型 `const V: i32 = 1; `
* Shadowing。在同一作用域内，可以重定义一个变量，例如`let guess = "123"; let guess = guess.parse().expect("error"); `，重定义时可以使用另一种类型。（只推荐类型转换或者近似语义使用）
# data type
* scala
  + integer
    - i8
    - u8
    - i16
    - u16
    - i32 (default)
    - u32
    - i64
    - u64
    - i128
    - u128
    - isize (arch)
    - usize
  + float
    - f32
    - f64 (default)
  + bool
    - true
    - false
  + char (4 bytes Unicode)
* compound
  + tuple
  + array

## tuple

```rust
let tup = (1, 2.0);

// destructuring
let (x, y) = tup;
// or
let x = tup.0;
let y = tup.1;
```

## array

```rust
let a = [1, 2, 3, 4];
let a: [i32; 3] = [1, 2, 3];
let a = [3; 4]; // [3, 3, 3, 3];
```

# function

```rust
fn f1() {
    println!("test");
}

fn f2() -> i32 {
    // statements ...

    // expression
    3
}

fn f3() -> i32 {
    return 3;
}
```

## expression

```rust
let x = {
  let z = 1;
  z + 1
};
```

# control flow

## if

```rust
let x = 4;
// if condition must be bool
if x > 3 {

} else if x < 0 {

} else {

}

if x > 3 {

} else if x < 0 {

}

// if is an expression
let number = if x > 3 { 5 } else { 6 };
```

## loop

```rust
loop {
  println!("4");
}
```

```rust
// nested loop
let mut count = 0;
'counting_up: loop {
println!("count = {}", count);
let mut remaining = 10;

loop {
    println!("remaining = {}", remaining);
    if remaining == 9 {
        break;
    }
    if count == 2 {
        break 'counting_up;
    }
    remaining -= 1;
}

count += 1;
}
println!("End count = {}", count);

```

```rust
// loop is an expression
let mut counter = 0;

let result = loop {
    counter += 1;

    if counter == 10 {
        break counter * 2;
    }
};

println!("The result is {}", result);
```

## while

```rust
let x = 1;
while x > 0 {

}

```

## for

```rust
let arr = [1, 3, 4];
for elem in arr {

}

for x in 1..3 {
    println!("{}", x);
}
```

# ownership

[what-is-ownership](https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html)

## reference

`reference` 可以视作指向常量的指针常量，它不可以被修改，也不可以修改它指向的内容。

```rust
let s = String::from("123");
// error
s = String::from("456");

// error
s.push_str("456");
```

### mutable reference

```rust
let mut s = String::from("123");
// push_str receive a '&mut String' parameter
s.push_str("456");
```

同一时刻只能有一个可变引用，通过这种限制可以避免数据竞争的情况出现。

```rust
let mut s = String::from("123");

// error
let s1 = &mut s;
let s2 = &mut s;
```

可以通过创建新的作用域允许多个可变引用（打破同一时刻的条件）。

```rust
let mut s = String::from("123");

{
  let s1 = &mut s;
  // use
}

let s2 = &mut s;
```

同样，同一时间不允许同时出现可变引用和不可变引用，不可变引用的用户不希望在使用过程中其内容发生变化。

```rust
let mut s = String::from("123");

let s1 = &s;
// error
let s2 = &mut s;
```

如果不可变引用的生命周期结束，那么可以创建一个可变引用。

```rust
let mut s = String::from("123");

let s1 = &s;
println!("{}", s1);

// ok
let s2 = &mut s;
// never use s1
```

### 空悬引用

`rust` 不允许出现空悬引用。

```rust
fn main() {
    let reference_to_nothing = dangle();
}

fn dangle() -> &String { // dangling reference
    let s = String::from("hello");

    &s
} // out of scope, s is dropped
```

# struct

```rust
struct User {
    active: bool,
    username: String,
    email: String,
    sign_in_count: u64,
}

fn main() {
  let user1 = User {
      email: String::from("someone@example.com"),
      username: String::from("someusername123"),
      active: true,
      sign_in_count: 1,
  };
  println!("{}", user1.email);
}
```

`rust` 不允许仅标记部分字段为mutable，如果想要修改struct实例，必须标记整个实例为mutable。

```rust
let mut user2 = User {
    email: String::from("someone@example.com"),
    username: String::from("someusername123"),
    active: true,
    sign_in_count: 1,
};
user2.email = String::from("anotheremail@example.com");
```

当变量名称和字段名称相同时，可以使用 `field init shorthand` 语法。

```rust
fn build_user(email: String, username: String) -> User {
    User {
        email,
        username,
        active: true,
        sign_in_count: 1,
    }
}
```

如果想要基于一个旧实例创建新实例，可以使用 `struct update syntax` 。

```rust
let user2 = User {
    email: String::from("another@example.com"),
    ..user1
};
```

注意， `struct update syntax` 也是 `move` 语义，因此 `user2` 构造完成后， `user1` 将不再合法。如果所有字段都是 `copy` 或者 `move` 语义的字段不从旧实例构造，那么旧实例仍然是合法的。

```rust
let user2 = User {
    email: String::from("another@example.com"),
    username: String::from("another"),
    ..user1
};
// user1 is valid
```

## tuple struct

```rust
struct Color(i32, i32, i32);
struct Point(i32, i32, i32);

let black = Color(0, 0, 0);
let origin = Point(0, 0, 0);
```

## unit-like struct

```rust
struct AlwaysEqual;

let subject = AlwaysEqual;
```

## print

如果想要使用 `println!("{}", instance)` 打印实例，那么struct必须实现 `std::fmt::Display`  `trait` 。另外，可以通过 `{:?}`  `{:#?} (for pretty-print)` 这两种方式打印，这要求struct实现 `Debug`  `trait` ， `rust` 提供了一个便捷的方式 `#[derive(Debug)]` 。

```rust
#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

fn main() {
    let rect = Rect {
        width: 10,
        height: 2,
    };
    println!("{:?}", rect);
    // Rect { width: 10, height: 2 }

    println!("{:#?}", rect);
    // Rect {
    //     width: 10,
    //     height: 2,
    // }
}
```

## method

使用 `impl` 为struct定义方法，每个struct可以有多个 `impl` 块。

```rust
#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    // &self是self: &Self的简写，Self为这个impl块对应struct类型的别名
    fn area(&self) -> u32 {
        self.width * self.height
    }

    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }

    // associated functions
    fn square(size: u32) -> Rectangle {
        Rectangle {
            width: size,
            height: size,
        }
    }
}

fn main() {
    let rect1 = Rectangle {
        width: 30,
        height: 50,
    };
    println!(
        "The area of the rectangle is {} square pixels.",
        rect1.area()
    );

    let sq = Rectangle::square(3);
}
```

# enum

```rust
enum IpAddrKind {
    V4,
    V6,
}

let four = IpAddrKind::V4;
let six = IpAddrKind::V6;

fn route(ip_kind: IpAddrKind) {}
```

你可以为每个枚举定义绑定值，它们的结构不需要完全一致。

```rust
enum IpAddr {
    V4(u8, u8, u8, u8),
    V6(String),
}

let home = IpAddr::V4(127, 0, 0, 1);

let loopback = IpAddr::V6(String::from("::1"));
```

你可以为枚举类型定义方法。

```rust
impl IpAddr {
  fn call(&self) {

  }
}
```

## match

```rust
#[derive(Debug)] // so we can inspect the state in a minute
enum UsState {
    Alabama,
    Alaska,
    // --snip--
}

enum Coin {
    Penny,
    Nickel,
    Dime,
    Quarter(UsState),
}

fn value_in_cents(coin: Coin) -> u8 {
    match coin {
        Coin::Penny => 1,
        Coin::Nickel => 5,
        Coin::Dime => 10,
        Coin::Quarter(state) => {
            println!("State quarter from {:?}!", state);
            25
        }
    }
}
```

`match` 需要是详尽的，如果某个可能没有被枚举，那么编译将会失败。

```rust
fn plus_one(x: Option<i32>) -> Option<i32> {
    match x {
        Some(i) => Some(i + 1),
    }
}
```

```shell
$ cargo run
   Compiling enums v0.1.0 (file:///projects/enums)
error[E0004]: non-exhaustive patterns: `None` not covered
   --> src/main.rs:3:15
    |
3   |         match x {
    |               ^ pattern `None` not covered
    |
    = help: ensure that all possible cases are being handled, possibly by adding wildcards or more match arms
    = note: the matched value is of type `Option<i32>`

For more information about this error, try `rustc --explain E0004`.
error: could not compile `enums` due to previous error
```

如果只想处理部分场景，可以使用 `catch-all` 模式。

```rust
let dice_roll = 9;
match dice_roll {
    3 => add_fancy_hat(),
    7 => remove_fancy_hat(),
    other => move_player(other),
}

// or
let dice_roll = 9;
match dice_roll {
    3 => add_fancy_hat(),
    7 => remove_fancy_hat(),
    // _ placeholder
    _ => reroll(),
}

// or
let dice_roll = 9;
match dice_roll {
    3 => add_fancy_hat(),
    7 => remove_fancy_hat(),
    // do nothing
    _ => (),
}

fn add_fancy_hat() {}
fn remove_fancy_hat() {}
fn move_player(num_spaces: u8) {}
fn reroll() {}
```

如果不想使用枚举绑定的值，那么也可以通过 `_` 忽略。

```rust
fn test(x: Option<i32>) -> Option<i32> {
    match x {
        None => None,
        Some(_) => Some(1),
    }
}
```

## if let

当只想匹配一个场景并忽略其他场景时，可以使用 `if let` 语法来避免模板代码。

```rust
let config_max = Some(3u8);
match config_max {
    Some(max) => println!("The maximum is configured to be {}", max),
    _ => (),
}

// equals

let config_max = Some(3u8);
if let Some(max) = config_max {
    println!("The maximum is configured to be {}", max);
}
```

使用 `if let` 语法会让你失去 `match` 强制的详尽检查，因此使用此语法时需要做权衡，你可以增加一个 `else` 分支来处理这个问题。

```rust
let mut count = 0;
if let Coin::Quarter(state) = coin {
    println!("State quarter from {:?}!", state);
} else {
    count += 1;
}
```

# package, crate, module

[managing-growing-projects-with-packages-crates-and-modules](https://doc.rust-lang.org/book/ch07-00-managing-growing-projects-with-packages-crates-and-modules.html)

# collections

## Vec<T>

```rust
let v: Vec<i32> = Vec::new();
// or
let v = vec![1, 2, 3];
```

```rust
// notice mut
let mut v = Vec::new();

v.push(5);
v.push(6);
v.push(7);
v.push(8);
```

```rust
let v = vec![1, 2, 3, 4, 5];

let third: &i32 = &v[2];
println!("The third element is {}", third);

match v.get(2) {
    Some(third) => println!("The third element is {}", third),
    None => println!("There is no third element."),
}
```

```rust
let v = vec![100, 32, 57];
for i in &v {
    println!("{}", i);
}

let mut v = vec![100, 32, 57];
for i in &mut v {
    *i += 50;
}
```

```rust
enum SpreadsheetCell {
    Int(i32),
    Float(f64),
    Text(String),
}

let row = vec![
    SpreadsheetCell::Int(3),
    SpreadsheetCell::Text(String::from("blue")),
    SpreadsheetCell::Float(10.12),
];

```

## String

```rust
let mut s = String::new();

let data = "initial contents";
let s = data.to_string();
// the method also works on a literal directly:
let s = "initial contents".to_string();

let s = String::from("initial contents");
```

```rust
let mut s = String::from("foo");
s.push_str("bar");
s.push('l');

let s1 = String::from("Hello, ");
let s2 = String::from("world!");
// fn add(self, s: &str) -> String
let s3 = s1 + &s2; // note s1 has been moved here and can no longer be used

let s1 = String::from("tic");
let s2 = String::from("tac");
let s3 = String::from("toe");

let s = format!("{}-{}-{}", s1, s2, s3);
```

`String` 是 `Vec<u8>` 的封装，因此不能使用下标语法获取值。

```rust
for c in "你好".chars() {
    println!("{}", c);
}
```

## HashMap<K, V>

```rust
use std::collections::HashMap;

let mut scores = HashMap::new();

scores.insert(String::from("Blue"), 10);
scores.insert(String::from("Yellow"), 50);
```

```rust
use std::collections::HashMap;

let field_name = String::from("Favorite color");
let field_value = String::from("Blue");

let mut map = HashMap::new();
map.insert(field_name, field_value);
// field_name and field_value are invalid at this point, try using them and
// see what compiler error you get!
```

```rust
use std::collections::HashMap;

let mut scores = HashMap::new();

scores.insert(String::from("Blue"), 10);
scores.insert(String::from("Yellow"), 50);

let team_name = String::from("Blue");
// Some(&10)
let score = scores.get(&team_name);
// 注意，你也可以通过index语法获取key对应的值，但是如果key不存在，那么程序将会panic
// error
let v = scores[&String::from("test")];

for (key, value) in &scores {
    println!("{}: {}", key, value);
}
```

```rust
use std::collections::HashMap;

let mut scores = HashMap::new();

scores.insert(String::from("Blue"), 10);
// replace
scores.insert(String::from("Blue"), 25);

// insert if not exist
scores.entry(String::from("Yellow")).or_insert(50);
scores.entry(String::from("Blue")).or_insert(50);

let text = "hello world wonderful world";
let mut map = HashMap::new();
// update with old value
for word in text.split_whitespace() {
    let count = map.entry(word).or_insert(0);
    *count += 1;
}
```

# error handling

`rust` 将错误分为可恢复和不可恢复两类。

## panic

`panic` 属于不可恢复的错误。可以显式调用 `panic!` 使程序停止执行，

```rust
fn main() {
    panic!("crash and burn");
}
```

output:

```
$ cargo run
   Compiling panic v0.1.0 (file:///projects/panic)
    Finished dev [unoptimized + debuginfo] target(s) in 0.25s
     Running `target/debug/panic`
thread 'main' panicked at 'crash and burn', src/main.rs:2:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

如果想要看到调用栈，那么需要设置 `RUST_BACKTRACE` 环境变量。

```rust
fn main() {
    let v = vec![1, 2, 3];

    v[99];
}
```

```
$ RUST_BACKTRACE=1 cargo run
thread 'main' panicked at 'index out of bounds: the len is 3 but the index is 99', src/main.rs:4:5
stack backtrace:
   0: rust_begin_unwind
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/std/src/panicking.rs:483
   1: core::panicking::panic_fmt
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/core/src/panicking.rs:85
   2: core::panicking::panic_bounds_check
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/core/src/panicking.rs:62
   3: <usize as core::slice::index::SliceIndex<[T]>>::index
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/core/src/slice/index.rs:255
   4: core::slice::index::<impl core::ops::index::Index<I> for [T]>::index
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/core/src/slice/index.rs:15
   5: <alloc::vec::Vec<T> as core::ops::index::Index<I>>::index
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/alloc/src/vec.rs:1982
   6: panic::main
             at ./src/main.rs:4
   7: core::ops::function::FnOnce::call_once
             at /rustc/7eac88abb2e57e752f3302f02be5f3ce3d7adfb4/library/core/src/ops/function.rs:227
note: Some details are omitted, run with `RUST_BACKTRACE=full` for a verbose backtrace.
```

上面的信息需要启用 `debug symbol` ，如果通过 `--release` 方式运行，那么将不会得到详细的调用栈信息。

## Result<T, E>

大多数错误并没有严重到使程序停止运行，它们可以通过程序进行一些替代性处理。 `rust` 提供了 `Result` 枚举表示这种可恢复的错误。

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

```rust
use std::fs::File;

fn main() {
    let f = File::open("hello.txt");

    let f = match f {
        Ok(file) => file,
        Err(error) => panic!("Problem opening the file: {:?}", error),
    };
}
```

你也可以针对错误类型做不同的处理。

```rust
use std::fs::File;
use std::io::ErrorKind;

fn main() {
    let f = File::open("hello.txt");

    let f = match f {
        Ok(file) => file,
        Err(error) => match error.kind() {
            ErrorKind::NotFound => match File::create("hello.txt") {
                Ok(fc) => fc,
                Err(e) => panic!("Problem creating the file: {:?}", e),
            },
            other_error => {
                panic!("Problem opening the file: {:?}", other_error)
            }
        },
    };
}
```

上面的代码中存在了过多的 `match` 原语，你可以通过 `Result` 提供的方法配合闭包让代码更加简洁。

```rust
use std::fs::File;
use std::io::ErrorKind;

fn main() {
    let f = File::open("hello.txt").unwrap_or_else(|error| {
        if error.kind() == ErrorKind::NotFound {
            File::create("hello.txt").unwrap_or_else(|error| {
                panic!("Problem creating the file: {:?}", error);
            })
        } else {
            panic!("Problem opening the file: {:?}", error);
        }
    });
}
```

使用 `unwrap`  `expect` 方法也可以简化 `match` 。

```rust
use std::fs::File;

fn main() {
    let f = File::open("hello.txt").unwrap();
    let f = File::open("hello.txt").expect("Failed to open hello.txt");
}
```

### 传递错误

```rust
use std::fs::File;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    let f = File::open("hello.txt");

    let mut f = match f {
        Ok(file) => file,
        Err(e) => return Err(e),
    };

    let mut s = String::new();

    match f.read_to_string(&mut s) {
        Ok(_) => Ok(s),
        Err(e) => Err(e),
    }
}
```

为了简化错误传递操作， `rust` 提供了 `?` 操作符。

```rust
use std::fs::File;
use std::io;
use std::io::Read;

fn read_username_from_file() -> Result<String, io::Error> {
    let mut f = File::open("hello.txt")?;
    let mut s = String::new();
    f.read_to_string(&mut s)?;
    Ok(s)
}

// or
fn read_username_from_file() -> Result<String, io::Error> {
    let mut s = String::new();

    File::open("hello.txt")?.read_to_string(&mut s)?;

    Ok(s)
}
```

# Generic Types, Traits, and Lifetimes

## Generic Type

```rust
fn largest<T>(list: &[T]) -> T {
}

struct Point<T> {
    x: T,
    y: T,
}

struct Point<T, U> {
    x: T,
    y: U,
}

enum Option<T> {
    Some(T),
    None,
}

enum Result<T, E> {
    Ok(T),
    Err(E),
}

impl<T> Point<T> {
    fn x(&self) -> &T {
        &self.x
    }
}

impl Point<f32> {
    fn distance_from_origin(&self) -> f32 {
        (self.x.powi(2) + self.y.powi(2)).sqrt()
    }
}

```

## Trait

```rust
pub trait Summary {
    fn summarize(&self) -> String;
}

pub struct NewsArticle {
    pub headline: String,
    pub location: String,
    pub author: String,
    pub content: String,
}

impl Summary for NewsArticle {
    fn summarize(&self) -> String {
        format!("{}, by {} ({})", self.headline, self.author, self.location)
    }
}

pub struct Tweet {
    pub username: String,
    pub content: String,
    pub reply: bool,
    pub retweet: bool,
}

impl Summary for Tweet {
    fn summarize(&self) -> String {
        format!("{}: {}", self.username, self.content)
    }
}
```

```rust
pub struct NewsArticle {
    pub headline: String,
    pub location: String,
    pub author: String,
    pub content: String,
}

impl Summary for NewsArticle {
    fn summarize(&self) -> String {
        format!("{}, by {} ({})", self.headline, self.author, self.location)
    }
}

pub struct Tweet {
    pub username: String,
    pub content: String,
    pub reply: bool,
    pub retweet: bool,
}

impl Summary for Tweet {
    fn summarize(&self) -> String {
        format!("{}: {}", self.username, self.content)
    }
}
```

你可以为 `Trait` 提供默认实现。

```rust
pub trait Summary {
    fn summarize(&self) -> String {
        String::from("(Read more...)")
    }
}

impl Summary for Tweet {}
```

默认实现可以调用 `Trait` 的其他方法，不管它们有没有默认实现。

```rust
pub trait Summary {
    fn summarize_author(&self) -> String;

    fn summarize(&self) -> String {
        format!("(Read more from {}...)", self.summarize_author())
    }
}
```

### `Trait` 作为参数

```rust
pub fn notify(item: &impl Summary) {
    println!("Breaking news! {}", item.summarize());
}
```

`rust` 提供了一个语法糖 `trait bound` ，如下所示，它和上面 `impl Trait` 的实现是一样的。

```rust
pub fn notify<T: Summary>(item: &T) {
    println!("Breaking news! {}", item.summarize());
}
```

对于简单的函数声明来说，使用 `impl Trait` 更加简洁，而 `trait bound` 可以用来表示其他复杂的情况。

```rust
pub fn notify(item1: &impl Summary, item2: &impl Summary) {
}

// better
pub fn notify<T: Summary>(item1: &T, item2: &T) {
}
```

你可以使用 `+` 操作符来指定多个 `trait bound` ，如下所示， `item` 参数必须同时实现 `Summary` 和 `Display` 两个 `Trait` 。

```rust
pub fn notify(item: &(impl Summary + Display));

pub fn notify<T: Summary + Display>(item: &T);
```

使用太多的 `trait bound` 会使代码难以阅读，你可以使用 `where` 语句来解决这个问题。

```rust
fn some_function<T: Display + Clone, U: Clone + Debug>(t: &T, u: &U) -> i32 {
}

fn some_function<T, U>(t: &T, u: &U) -> i32
    where T: Display + Clone,
          U: Clone + Debug,
{
}
```

### `Trait` 作为返回值

```rust
fn returns_summarizable() -> impl Summary {
    Tweet {
        username: String::from("horse_ebooks"),
        content: String::from(
            "of course, as you probably already know, people",
        ),
        reply: false,
        retweet: false,
    }
}
```

注意，你只可以在返回一种类型时使用 `impl Trait` 作为返回值。下面这段代码将无法通过编译。

```rust
fn returns_summarizable(switch: bool) -> impl Summary {
    if switch {
        NewsArticle {
            headline: String::from(
                "Penguins win the Stanley Cup Championship!",
            ),
            location: String::from("Pittsburgh, PA, USA"),
            author: String::from("Iceburgh"),
            content: String::from(
                "The Pittsburgh Penguins once again are the best \
                 hockey team in the NHL.",
            ),
        }
    } else {
        Tweet {
            username: String::from("horse_ebooks"),
            content: String::from(
                "of course, as you probably already know, people",
            ),
            reply: false,
            retweet: false,
        }
    }
}
```

### 使用 `Trait Bound` 有条件的实现方法

`cmp_display` 方法只会在 `T` 实现了 `Display` 和 `PartialOrd`  `Trait` 时才允许调用。

```rust
use std::fmt::Display;

struct Pair<T> {
    x: T,
    y: T,
}

impl<T> Pair<T> {
    fn new(x: T, y: T) -> Self {
        Self { x, y }
    }
}

impl<T: Display + PartialOrd> Pair<T> {
    fn cmp_display(&self) {
        if self.x >= self.y {
            println!("The largest member is x = {}", self.x);
        } else {
            println!("The largest member is y = {}", self.y);
        }
    }
}
```

你可以对任何已经实现了其他 `Trait` 的类型有条件的实现一个 `Trait` 。在满足 `Trait Bound` 的任何类型上实现 `Trait` 称为 `blanket implementations` ，这在标准库中广泛应用。例如，标准库为任何实现了 `Display`  `Trait` 的类型实现 `ToString`  `Trait` 。

```rust
impl<T: Display> ToString for T {
    // --snip--
}
```

## Lifetime

[lifetime-syntax](https://doc.rust-lang.org/book/ch10-03-lifetime-syntax.html)

# Test

在方法定义上标记 `#[test]` 将会把这个方法作为一个测试用例。

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
```

执行 `cargo test` 命令将会运行所有测试用例。

# workspace

随着项目开发，单个 `lib crate` 将会变的过于庞大，因此需要将其拆分为多个 `lib crate` 以便更好的管理。 `rust` 提供了 `workspace` 特性帮忙管理多个相关的 `crate` 。

## create

一个 `workspace` 由一组 `package` 组成，它们共享同一个 `Cargo.lock` 和 `output` 文件夹（避免重复构建，同时使所有 `crate` 的依赖保持一致）。

首先为 `workspace` 创建一个文件夹，然后创建一个 `Cargo.toml` 文件，它用于配置整个 `workspace` 。

```sh
$ mkdir add
$ cd add
$ touch Cargo.toml
```

它不包含 `[package]` 区块等元信息，作为代替，它以 `[workspace]` 区块为始，这个区块允许我们通过指定 `crate` 的路径来将其增加到 `workspace` 中。例如，下面的配置增加了一个 `binary crate`  `adder` 。

```toml
[workspace]

members = [
    "adder",
]
```

接下来，通过 `cargo new` 命令创建 `adder`  `crate` 。

```sh
$ cargo new adder
```

此时运行 `cargo build` ，文件结构如下所示：

```
├── Cargo.lock
├── Cargo.toml
├── adder
│   ├── Cargo.toml
│   └── src
│       └── main.rs
└── target
```

接下里，创建 `lib crate`  `add-one` 。首先将其增加到 `members` 列表中。

```toml
[workspace]

members = [
    "adder",
    "add-one",
]
```

然后创建名为 `add-one` 的 `lib crate` 。

```sh
$ cargo new add-one --lib
```

此时文件结构如下所示：

```
├── Cargo.lock
├── Cargo.toml
├── add-one
│   ├── Cargo.toml
│   └── src
│       └── lib.rs
├── adder
│   ├── Cargo.toml
│   └── src
│       └── main.rs
└── target
```

## run

然后，在 `add-one` 中增加 `add_one` 函数。

```rust
pub fn add_one(x: i32) -> i32 {
    x + 1
}
```

如果想要在 `adder` 中使用，那么将 `add-one` 增加到 `adder/Cargo.toml` 中。

```toml
[package]
name = "adder"
version = "0.1.0"
edition = "2021"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]

add-one = { path = "../add-one" }
```

然后就可以在 `adder` 中使用 `add-one` 提供的所有接口。

```rust
use add_one;

fn main() {
    let num = 10;
    println!(
        "Hello, world! {} plus one is {}!",
        num,
        add_one::add_one(num)
    );
}
```

如果想要运行 `add`  `workspace` 中的 `binary crate` ，需要通过 `-p` 参数指定包名。

```sh
$ cargo run -p adder
    Finished dev [unoptimized + debuginfo] target(s) in 0.0s
     Running `target/debug/adder`
Hello, world! 10 plus one is 11!
```

## external package

由于整个 `workspace` 只有一个 `Cargo.lock` 文件，所有 `crate` 将会使用相同依赖的同一个版本。另外，依赖不会进行传递，如果想要在多个 `crate` 中使用同一个依赖，那么需要在每个 `crate` 的 `Cargo.toml` 中都增加那个依赖。如果多个 `crate` 中指定同一个依赖的版本不兼容（ `cargo` 会确保所有 `crate` 使用同一个版本），那么将无法通过编译。

# smart pointer

`reference` 和 `smart pointer` 都是指针的一种， `reference` 只借取数据，而 `smart pointer` 拥有它所指向的数据。

`smart pointer` 一般通过 `struct` 实现，它们和普通 `struct` 不同的地方在于它们实现了 `Defer` 和 `Drop`  `Trait` 。 `Defer`  `Trait` 允许 `smart pointer` 的实现表现的像 `reference` ，因此其他代码可以同时和这两种类型一起工作。 `Drop`  `Trait` 允许自定义实例销毁逻辑，当实例退出作用域时， `rust` 编译器会自动加上此逻辑。

标准库提供了几个 `smart pointer` 的实现：
* Box<T>
* Rc<T>
* Ref<T> / RefMut<T>

## Box<T>

`Box<T>` 允许你讲数据存在堆上而非栈上，同时它不会产生性能开销，但是它也没有其他更多能力。你可以在以下场景使用它：

* 当你拥有一个编译时无法确定大小的类型，但是想要在需要精确大小的上下文中使用它
* 当你拥有一个很大的数据并且想要转移它的所有权，但是不想发生拷贝
* 当你想要拥有一个值，并且你只关心它实现的`Trait`而非特定类型

```rust
fn main() {
    let b = Box::new(5);
    println!("b = {}", b);
}
```

通过 `Box<T>` 你可以定义递归类型。例如下面的 `List` 类型，它无法通过编译，因为编译器无法确定 `Cons` 的大小。

```rust
enum List {
    Cons(i32, List),
    Nil,
}
```

使用 `Box<T>` 封装 `List` 后，编译器可以确定 `Cons` 实例的大小由一个 `i32` 和一个 `usize` 大小的指针组成。

```rust
enum List {
    Cons(i32, Box<List>),
    Nil,
}

use crate::List::{Cons, Nil};

fn main() {
    let list = Cons(1, Box::new(Cons(2, Box::new(Cons(3, Box::new(Nil))))));
}
```

* [ `Deref Trait` ](https://doc.rust-lang.org/book/ch15-02-deref.html)
* [ `Drop Trait` ](https://doc.rust-lang.org/book/ch15-03-drop.html)

## Rc<T>

`Rc<T>` 是基于引用计数的 `smart pointer` 。大部分情况下，你都能确定哪个变量持有特定的值，但是有时候一个值可能会存在多个持有者，例如图数据结构中的节点。

当想要在程序的多个部分使用分配在堆上的数据，同时无法在编译期确定哪一部分代码最终完成数据的使用时，可以使用 `Rc<T>` 来解决这个问题。

注意， `Rc<T>` 只能在单线程环境下使用。

回到基于 `Box<T>` 实现的 `List` 数据结构，如果想要创建两个 `List` ，并且它们同时持有另一个 `List` ，如下所示：

```rust
enum List {
    Cons(i32, Box<List>),
    Nil,
}

use crate::List::{Cons, Nil};

fn main() {
    let a = Cons(5, Box::new(Cons(10, Box::new(Nil))));
    let b = Cons(3, Box::new(a));
    let c = Cons(4, Box::new(a));
}
```

上面的程序无法通过编译，因为 `b` 已经获取了 `a` 的所有权， `c` 无法再次获取。如果改变 `Cons` 的定义使它持有引用，那么需要指定 `lifetime` 参数，这会导致所有的元素都必须和整个 `List` 的生命周期一致。
