#!/usr/bin/env zx

let output = await $`ps aux | grep frps`
let result = output.stdout

if (!result.match(/-c/).length) {
  await $`frpc`
}

