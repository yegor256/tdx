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

require 'yaml'
require 'fileutils'

# TDX main module.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2017 Yegor Bugayenko
# License:: MIT
module TDX
  # Base class
  class Base
    def initialize(opts)
      @opts = opts
    end

    def svg
      dat = Tempfile.new('tdx.dat')
      version = `git --version`.split(/ /)[2]
      raise "git version #{version} is too old, upgrade it to 2.0+" unless
        Gem::Version.new(version) >= Gem::Version.new('2.0')
      path = checkout
      commits =
        `cd "#{path}" && git log '--pretty=format:%H %cI' --reverse`
        .split(/\n/)
        .map { |c| c.split(' ') }
      issues = issues(commits)
      commits.each do |sha, date|
        `cd "#{path}" && git checkout --quiet #{sha}`
        dat << "#{date} #{tests(path)} #{hoc(path)} #{files(path)}"
        dat << " #{loc(path)} #{issues[sha]}\n"
      end
      dat.close
      svg = Tempfile.new('tdx.svg')
      gpi = [
        "set output \"#{svg.path}\"",
        'set terminal svg size 700, 260',
        'set termoption font "monospace,10"',
        'set xdata time',
        'set timefmt "%Y-%m"',
        'set ytics format "%.0f%%" textcolor rgb "#81b341"',
        'set grid linecolor rgb "gray"',
        'set xtics format "%b/%y" font "monospace,8" textcolor rgb "black"',
        'set autoscale',
        'set style fill solid',
        'set boxwidth 0.75 relative',
        "plot \"#{dat.path}\" using 1:2 with boxes \
title \"Test HoC\" linecolor rgb \"#81b341\""
      ]
      `gnuplot -e '#{gpi.join(';')}' 2>/dev/null`
      FileUtils.rm_rf(path)
      File.delete(dat)
      xml = File.read(svg)
      File.delete(svg)
      xml
    end

    private

    def checkout
      dir = Dir.mktmpdir
      `cd #{dir} && git clone --quiet #{@opts[:repo]} .`
      dir
    end

    def files(path)
      Dir.glob("#{path}/**/*").size
    end

    def loc(path)
      cloc = `cd "#{path}" && cloc . --yaml --quiet 2>/dev/null`
      yaml = YAML.load(cloc)
      if yaml
        yaml['SUM']['code']
      else
        0
      end
    end

    def hoc(path)
      `cd "#{path}" && hoc`
    end

    def tests(path)
      `cd "#{path}" && hoc`
    end

    def issues(commits)
      dates = []
      # dates = github.issues.map{ |i| i.created_at }
      commits.map { |sha, date| [sha, dates.select { |d| d < date }.size] }.to_h
    end
  end
end
