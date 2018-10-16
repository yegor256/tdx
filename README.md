[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/tdx)](http://www.rultor.com/p/yegor256/tdx)
[![We recommend RubyMine](http://img.teamed.io/rubymine-recommend.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/yegor256/tdx.svg)](https://travis-ci.org/yegor256/tdx)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/tdx)](http://www.0pdd.com/p?name=yegor256/tdx)
[![Gem Version](https://badge.fury.io/rb/tdx.svg)](http://badge.fury.io/rb/tdx)
[![Dependency Status](https://gemnasium.com/yegor256/tdx.svg)](https://gemnasium.com/yegor256/tdx)
[![Code Climate](http://img.shields.io/codeclimate/github/yegor256/tdx.svg)](https://codeclimate.com/github/yegor256/tdx)
[![Coverage Status](https://img.shields.io/coveralls/yegor256/tdx.svg)](https://coveralls.io/r/yegor256/tdx)

## What This is for?

It's a simple command line tool to calculate your automated testing dynamics.
More about it here:
[The TDD That Works for Me](http://www.yegor256.com/2017/03/24/tdd-that-works.html).

## How to Install?

First, install
[gnuplot](http://www.gnuplot.info/)
and
[hoc](https://github.com/yegor256/hoc).

Install it first:

```bash
$ gem install tdx
```

## How to Run?

Run it locally and read its output:

```bash
$ tdx --help
```

This command, for example, will generate SVG graph for this repo:

```bash
$ tdx --tests=test/**/* --tests=features/**/* git@github.com:yegor256/tdx.git graph.svg
```

# How to contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure you build is green before you contribute
your pull request. You will need to have [Ruby](https://www.ruby-lang.org/en/) 2.3+ and
[Bundler](https://bundler.io/) installed. Then:

```
$ bundle update
$ rake
```

If it's clean and you don't see any error messages, submit your pull request.

## LICENSE

(The MIT License)

Copyright (c) 2017 Yegor Bugayenko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the 'Software'), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
