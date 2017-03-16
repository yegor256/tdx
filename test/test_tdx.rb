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
require 'tmpdir'
require 'minitest/autorun'
require 'slop'

# TDX main module test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2017 Yegor Bugayenko
# License:: MIT
class TestPDD < Minitest::Test
  def test_git_repo
    skip if Gem.win_platform?
    Dir.mktmpdir 'test' do |dir|
      raise unless system("
        set -e
        cd '#{dir}'
        git init --quiet repo
        cd repo
        git config user.email yegor256@gmail.com
        git config user.name 'Mr. Tester'
        echo 'a = 1' > 1.rb && git add 1.rb && git commit -qam '1'
        rm 1.rb
        echo '<?php b = 2' > 2.php && git add 2.php && git commit -qam '2'
        mkdir tests
        echo 'c = 3' > tests/3.py && git add tests/3.py && git commit -qam '3'
      ")
      assert(
        TDX::Base.new(
          "file:///#{File.join(dir, 'repo')}",
          opts(['--tests', 'tests/**/*'])
        ).svg.include?('<path ')
      )
    end
  end

  def test_real_github_repo
    assert(
      TDX::Base.new(
        'https://github.com/yegor256/empty.git',
        opts(['--tests', 'src/test/**/*'])
      ).svg.include?('<path ')
    )
  end

  private

  def opts(args)
    Slop.parse args do |o|
      o.array '-t', '--tests'
      o.string '--sha'
    end
  end
end
