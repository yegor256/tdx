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

require 'date'
require 'yaml'
require 'octokit'
require 'fileutils'
require 'English'
require 'tdx/exec'

# TDX main module.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2017 Yegor Bugayenko
# License:: MIT
module TDX
  # Base class
  class Base
    def initialize(uri, opts)
      @uri = uri
      @opts = opts
    end

    def svg
      dat = Tempfile.new('tdx')
      version = Exec.new('git --version').stdout.split(/ /)[2]
      raise "git version #{version} is too old, upgrade it to 2.0+" unless
        Gem::Version.new(version) >= Gem::Version.new('2.0')
      path = checkout

      commits = Exec.new('git log "--pretty=format:%H %cI" --reverse', path)
        .stdout.split(/\n/).map { |c| c.split(' ') }
      issues = issues(commits)
      puts "Date\t\t\tTest\tHoC\tFiles\tLoC\tIssues\tSHA"
      commits.each do |sha, date|
        Exec.new("git checkout --quiet #{sha}", path).stdout
        line = "#{date[0, 16]}\t#{tests(path)}\t#{hoc(path)}\t#{files(path)}\t\
#{loc(path)}\t#{issues[sha]}\t#{sha[0, 7]}"
        dat << "#{line}\n"
        puts line
      end
      dat.close
      svg = Tempfile.new('tdx')
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
        [
          "plot \"#{dat.path}\" using 1:2 with boxes",
          'title "Test HoC" linecolor rgb "#81b341"',
          ', "" using 1:3 with boxes title "HoC" linecolor rgb "red"',
          ', "" using 1:4 with boxes title "Files" linecolor rgb "black"',
          ', "" using 1:5 with boxes title "LoC" linecolor rgb "cyan"',
          ', "" using 1:6 with boxes title "Issues" linecolor rgb "orange"'
        ].join(' ')
      ]
      Exec.new("gnuplot -e '#{gpi.join('; ')}'").stdout
      FileUtils.rm_rf(path)
      File.delete(dat)
      xml = File.read(svg)
      File.delete(svg)
      xml
    end

    private

    def checkout
      dir = Dir.mktmpdir
      Exec.new("git clone --quiet #{@uri} .", dir).stdout
      size = Dir.glob(File.join(dir, '**/*'))
        .map(&:size)
        .inject(0) { |a, e| a + e }
      puts "Cloned #{@uri} (#{size / 1024}Kb) into temporary directory"
      dir
    end

    def files(path)
      Dir.glob("#{path}/**/*").size
    end

    def loc(path)
      yaml = YAML.load(Exec.new('cloc . --yaml --quiet', path).stdout)
      if yaml
        yaml['SUM']['code']
      else
        0
      end
    end

    def hoc(path)
      Exec.new('hoc', path).stdout.strip
    end

    def tests(path)
      Exec.new('hoc', path).stdout.strip
    end

    def issues(commits)
      dates = if @uri.include?('github.com')
        client = if @opts[:login]
          Octokit::Client.new(login: @opts[:login], password: @opts[:password])
        else
          Octokit::Client.new
        end
        repo = if @uri.start_with?('git@')
          @uri.gsub(/^git@github\.com:|\.git$/, '')
        else
          @uri.gsub(%r{^https://github\.com/|\.git$}, '')
        end
        list = client.list_issues(repo, state: :all).map(&:created_at)
        puts "Loaded #{list.length} issues from GitHub repo '#{repo}'"
        list
      else
        []
      end
      commits.map do |sha, date|
        iso = Time.parse(date)
        [sha, dates.select { |d| d < iso }.size]
      end.to_h
    end
  end
end
