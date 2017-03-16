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
require 'nokogiri'
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
      @issues = nil
      @pure = nil
      @hoc = nil
      @logopts = '--ignore-space-change --no-color --find-copies-harder \
--ignore-all-space --ignore-submodules -M --diff-filter=ACDM'
    end

    def svg
      version = Exec.new('git --version').stdout.split(/ /)[2]
      raise "git version #{version} is too old, upgrade it to 2.0+" unless
        Gem::Version.new(version) >= Gem::Version.new('2.0')
      path = checkout
      commits = Exec.new(
        "git log '--pretty=format:%H %cI' #{@logopts} " +
        (@opts[:sha] ? @opts[:sha] : 'HEAD'),
        path
      ).stdout.split(/\n/).map { |c| c.split(' ') }
      puts "Date\t\t\tCode\tTests\tIssues\tSHA\tIdx"
      metrics = commits.each_with_index.map do |c, i|
        Exec.new("git checkout --quiet --force #{c[0]}", path).stdout
        pure = pure(path, c[0])
        m = {
          date: c[1],
          code: pure,
          tests: hoc(path, c[0]) - pure,
          issues: issues(commits)[c[0]],
          sha: c[0]
        }
        puts "#{m[:date][0, 16]}\t#{m[:code]}\t#{m[:tests]}\t\
#{m[:issues]}\t#{m[:sha][0, 7]}\t#{i}/#{commits.size}"
        m
      end
      dat = if @opts[:data]
        File.new(@opts[:data], 'w+')
      else
        Tempfile.new('tdx')
      end
      metrics.select { |m| m[:code] > 0 }.each do |m|
        dat << [
          m[:date],
          m[:code],
          m[:tests],
          m[:issues],
          m[:sha]
        ].join(' ') + "\n"
      end
      dat.close
      svg = Tempfile.new('tdx')
      gpi = [
        "set output \"#{svg.path}\"",
        'set terminal svg size 720, 360',
        'set lmargin 7',
        'set rmargin 5',
        'set termoption font "monospace,10"',
        'set xdata time',
        'set border lc rgb "gray"',
        'set style fill solid',
        'set boxwidth 0.75 relative',
        'set timefmt "%Y-%m"',
        'set grid linecolor rgb "gray"',
        'set autoscale y',
        'set multiplot layout 2,1',
        'set ytics format "%.0fK" textcolor rgb "black"',
        'set y2tics format "%.0f" textcolor rgb "#DA6D1A"',
        'set autoscale y2',
        'unset xtics',
        [
          "plot \"#{dat.path}\"",
          ' u 1:($2/1000) w l t "Code" lw 2 lc rgb "#2B7947"',
          ', "" u 1:($3/1000) w l t "Tests" lw 2 lc rgb "#C80604"',
          ', "" u 1:4 w l t "Issues" lc rgb "#DA6D1A" axes x1y2'
        ].join(' '),
        'unset y2tics',
        'unset title',
        'set tmargin 0',
        'set xtics format "%b/%y" font "monospace,8" textcolor rgb "gray"',
        'set ytics format "%.0f%%" textcolor rgb "#C80604"',
        [
          "plot \"#{dat.path}\"",
          'u 1:(100*$3/($2+$3)) pt 7 ps 1 lc rgb "#C80604" notitle'
        ].join(' '),
        'unset multiplot'
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
      size = Dir.glob(File.join(dir, '**', '*')).map(&:size).inject(:+)
      puts "Cloned #{@uri} (#{size / 1024}Kb) into temporary directory"
      dir
    end

    def pure(path, sha)
      @pure = hashes(path, @opts[:tests]) if @pure.nil?
      sum(@pure, sha)
    end

    def hoc(path, sha)
      @hoc = hashes(path, []) if @hoc.nil?
      sum(@hoc, sha)
    end

    def hashes(path, excludes)
      Exec.new(
        "git log --pretty=tformat:%H --numstat #{@logopts} -- . " +
excludes.map { |e| "':(exclude,glob)#{e}'" }.join(' '),
        path
      ).stdout.split(/(?=[0-9a-f]{40})/m).map do |t|
        lines = t.split("\n")
        [
          lines[0],
          lines.drop(2).map do |n|
            n.split(/\s+/).take(2).map(&:to_i).inject(:+)
          end.inject(:+) || 0
        ]
      end
    end

    def sum(hashes, sha)
      hashes.drop_while { |c| c[0] != sha }.map { |c| c[1] }.inject(:+) || 0
    end

    def issues(commits)
      return @issues unless @issues.nil?
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
        list = []
        p = 1
        loop do
          page = client.list_issues(
            repo, state: 'all', page: p
          ).map(&:created_at)
          break if page.empty?
          list.concat(page)
          puts "+#{page.length}/#{list.size} issues from GitHub"
          p += 1
        end
        puts "Loaded #{list.length} issues from GitHub repo '#{repo}'"
        list
      else
        []
      end
      @issues = commits.map do |sha, date|
        iso = Time.parse(date)
        [sha, dates.select { |d| d < iso }.size]
      end.to_h
    end
  end
end
