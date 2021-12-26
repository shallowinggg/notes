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
