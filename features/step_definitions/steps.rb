# encoding: utf-8
#
# Copyright (c) 2017 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'tdx'
require 'nokogiri'
require 'tmpdir'
require 'slop'
require 'English'

Before do
  @cwd = Dir.pwd
  @dir = Dir.mktmpdir('test')
  FileUtils.mkdir_p(@dir) unless File.exist?(@dir)
  Dir.chdir(@dir)
end

After do
  Dir.chdir(@cwd)
  FileUtils.rm_rf(@dir) if File.exist?(@dir)
end

Given(/^I have a Git repository in .\/repo$/) do
  raise unless system("
    set -e
    cd '#{@dir}'
    git init --quiet repo
    cd repo
    git config user.email yegor256@gmail.com
    git config user.name 'Mr. Tester'
    echo 'a = 1' > 1.rb && git add 1.rb && git commit -qam '1'
    echo '<?php b = 2' > 2.php && git add 2.php && git commit -qam '2'
    mkdir tests
    echo 'c = 3' > tests/3.py && git add tests/3.py && git commit -qam '3'
  ")
end

When(%r{^I run bin/tdx with "([^"]+)"$}) do |arg|
  home = File.join(File.dirname(__FILE__), '../..')
  @stdout = `ruby -I#{home}/lib #{home}/bin/tdx #{arg}`
  @exitstatus = $CHILD_STATUS.exitstatus
end

Then(/^Exit code is zero$/) do
  raise "Non-zero exit code #{@exitstatus}" unless @exitstatus == 0
end

Then(/^Exit code is not zero$/) do
  raise 'Zero exit code' if @exitstatus == 0
end

Then(/^SVG is valid in "([^"]+)"$/) do |path|
  raise "XML doesn't match \"#{xpath}\":\n#{@xml}" if \
    Nokogiri::load(path).xpath('/svg//path').empty?
end

Then(/^Stdout contains "([^"]*)"$/) do |txt|
  unless @stdout.include?(txt)
    raise "STDOUT doesn't contain '#{txt}':\n#{@stdout}"
  end
end

Given(/^It is Unix$/) do
  pending if Gem.win_platform?
end

Given(/^It is Windows$/) do
  pending unless Gem.win_platform?
end
