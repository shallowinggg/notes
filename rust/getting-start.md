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
