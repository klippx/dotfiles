Tools
-------------

The following static analysis tools are used in the project:
* [Rubocop](https://github.com/bbatsov/rubocop)
* [Coffeelint](https://github.com/clutchski/coffeelint)
* [Haml-lint](https://github.com/brigade/haml-lint)
* [SCSS-lint](https://github.com/brigade/scss-lint)
* [Codeclimate CLI](https://github.com/codeclimate/codeclimate)

#### Rubocop
* Project configuration found in `.rubocop.yml`
* Philosophy is that we are always able to run (and trust) what rubocop -a tells
  us.
* Installation instructions: None, it is a bundled gem
* Running it: `rubocop -a`

#### Coffeelint
* Project configuration found in `coffeelint.json` (same as Thoughbot/Hound)
* Philosophy is that coffeelint.json is the single source of truth.
* Installation instructions:
  1. `npm install coffeelint -g`
  2. Make sure `coffeelint` can be run
* Running it: `coffeelint -f coffeelint.json app/`

#### SCSS-lint
* Project configuration found in `.scss-lint.yml` (same as Thoughbot/Bourbon,
  Thoughbot/Bitters)
* Philosophy is that .scss-lint.yml is the single source of truth.
* Installation instructions: None, it is a bundled gem
* Running it: `scss-lint`

#### Haml-lint
* Project configuration found in `.haml-lint.yml` (same as Thoughbot/Hound)
* Philosophy is that .haml-lint.yml is the single source of truth.
* Installation instructions: None, it is a bundled gem
* Running it: `haml-lint app/`

Linting code
------------
There are plugins available for the certain editors that apply the same linting
styles as specified in the config files within the project. These plugins are
not standalone and need both a shared base linter package and their own specific
executables to be installed (available in the path) in order to work.

#### Atom

Errors will be instantly highlighted and pointed out as you type your code.

In order for everything to work
* https://atom.io/packages/linter
  * Rubocop, instructions:
    * https://atom.io/packages/linter-rubocop
    * Delete `"linter-rubocop": {}` from config.cson
    * Open atom using command line in project folder: `atom .`
  * https://atom.io/packages/linter-coffeelint
  * https://atom.io/packages/linter-scss-lint
  * https://atom.io/packages/linter-haml

#### Sublime Text 3

There will be a little bit of inline highlighting but error text is displayed at
the bottom left corner making it a bit hard to read. Some packages add gutter
hints.

Tip: Add an editor ruler at 80 (in the menu: View/Ruler) to get more visual aid.

* http://www.sublimelinter.com/en/latest/installation.html
* Package name `SublimeLinter`
  * Rubocop
    * Package name `SublimeLinter-rubocop`
    * https://github.com/SublimeLinter/SublimeLinter-rubocop
  * Coffeelint
    * Package name `SublimeLinter-coffeelint`
    * https://github.com/SublimeLinter/SublimeLinter-coffeelint
  * SCSS-lint
    * Package name `SublimeLinter-contrib-scss-lint`
    * https://github.com/attenzione/SublimeLinter-scss-lint
  * Haml-lint
    * Package name `SublimeLinter-contrib-haml-lint`
    * https://github.com/jeroenj/SublimeLinter-contrib-haml-lint
