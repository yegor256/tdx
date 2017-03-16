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
    end

    def svg
      version = Exec.new('git --version').stdout.split(/ /)[2]
      raise "git version #{version} is too old, upgrade it to 2.0+" unless
        Gem::Version.new(version) >= Gem::Version.new('2.0')
      path = checkout
      commits = Exec.new(
        'git log "--pretty=format:%H %cI" ' +
        (@opts[:sha] ? @opts[:sha] : 'HEAD'),
        path
      ).stdout.split(/\n/).map { |c| c.split(' ') }
      issues = issues(commits)
      puts "Date\t\t\tTest\tHoC\tFiles\tLoC\tIssues\tSHA\tIdx"
      metrics = commits.each_with_index.map do |c, i|
        Exec.new("git checkout --quiet #{c[0]}", path).stdout
        m = {
          date: c[1],
          pure: pure(path),
          hoc: hoc(path),
          files: files(path),
          loc: loc(path),
          issues: issues[c[0]],
          sha: c[0]
        }
        puts "#{m[:date][0, 16]}\t#{m[:pure]}\t#{m[:hoc]}\t#{m[:files]}\t\
#{m[:loc]}\t#{m[:issues]}\t#{m[:sha][0, 7]}\t#{i}/#{commits.size}"
        m
      end
      max = { pure: 0, hoc: 0, files: 0, loc: 0, issues: 0 }
      max = metrics.inject(max) do |m, t|
        {
          pure: [m[:pure], t[:pure], 1].max,
          hoc: [m[:hoc], t[:hoc], 1].max,
          files: [m[:files], t[:files], 1].max,
          loc: [m[:loc], t[:loc], 1].max,
          issues: [m[:issues], t[:issues], 1].max
        }
      end
      dat = if @opts[:data]
        File.new(@opts[:data], 'w+')
      else
        Tempfile.new('tdx')
      end
      metrics.each do |m|
        dat << [
          m[:date],
          100.0 * m[:pure] / max[:pure],
          100.0 * (m[:pure] - m[:hoc]) / (max[:pure] - max[:hoc]),
          100.0 * m[:hoc] / max[:hoc],
          100.0 * m[:files] / max[:files],
          100.0 * m[:loc] / max[:loc],
          100.0 * m[:issues] / max[:issues],
          m[:sha]
        ].join(' ') + "\n"
      end
      dat.close
      svg = Tempfile.new('tdx')
      gpi = [
        "set output \"#{svg.path}\"",
        'set terminal svg size 700, 260',
        'set termoption font "monospace,10"',
        'set xdata time',
        'set timefmt "%Y-%m"',
        'set ytics format "%.0f%%" textcolor rgb "black"',
        'set grid linecolor rgb "gray"',
        'set xtics format "%b/%y" font "monospace,8" textcolor rgb "black"',
        'set autoscale',
        'set style fill solid',
        'set boxwidth 0.75 relative',
        [
          "plot \"#{dat.path}\" using 1:3 with lines",
          'title "Test HoC" linecolor rgb "#81b341"',
          ', "" using 1:4 with lines title "HoC" linecolor rgb "red"',
          ', "" using 1:7 with lines title "Issues" linecolor rgb "orange"'
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
      Nokogiri::XML.parse(Exec.new('cloc . --xml --quiet', path).stdout)
        .xpath('/results/languages/total/@code')[0].to_s.to_i
    end

    def pure(path)
      exclude = if @opts[:tests]
        @opts[:tests].map { |e| "--exclude=#{e}" }
      else
        []
      end
      Exec.new(
        'hoc ' + exclude.join(' '),
        path
      ).stdout.strip.to_i
    end

    def hoc(path)
      Exec.new('hoc', path).stdout.strip.to_i
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
