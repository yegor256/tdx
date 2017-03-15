Feature: Command Line Processing
  As a repository owner I want to be able to
  call TDX as a command line tool

  Scenario: Help can be printed
    When I run bin/tdx with "-h"
    Then Exit code is zero
    And Stdout contains "--version"

  Scenario: Version can be printed
    When I run bin/tdx with "--version"
    Then Exit code is zero

  Scenario: Simple SVG is built
    Given I have a Git repository in ./repo
    When I run bin/tdx with "file://$(pwd)/repo pic.svg"
    Then Stdout is empty
    Then Exit code is zero
    And SVG is valid in "pic.svg"

