# <a id="top"></a>mkconfig

Tired from copy-pasting some basic configurations from one project to another? Generate them instead with this tool. By the way the dummy of this readme is generated with `mkconfig readme ./readme.md` command.

* [Quick demo](#quick-demo)
* [Installation](#installation)
* [Usage](#usage)
* [Development](#development)

## Quick demo

```sh
# Generate a sample readme file
mkconfig readme readme.md
```

[To top]

## Installation

```sh
# Checkout the repo
sudo git clone https://github.com/varlogerr/toolbox.mkconfig.git /opt/varlog/mkconfig
# Source to .bashrc
echo '. /opt/varlog/mkconfig/bin/mkconfig' >> ~/.bashrc
# Reload .bashrc
. ~/.bashrc
```

Sourcing to .bashrc does 2 things:
* adds the mkconfig `bin` directory to `PATH`
* registers basic bash completion for mkconfig

Alternatively you may want to install it to some PATH directory, then after checkout:

```sh
# Symlink to a PATH directory
sudo ln -s /opt/varlog/mkconfig/bin/mkconfig /use/local/bin/mkconfig
# Source to .bashrc
echo '. /use/local/bin/mkconfig' >> ~/.bashrc
# Reload .bashrc
. ~/.bashrc
```

[To top]

## Usage

```sh
# View the tool help
mkconfig -h
# List available module
mkconfig -l
# View a module help
mkconfig MODULE -h
```

[To top]

## Development

Currenly only the most urgent for me modules are added. Want to contribute? Copy-paste a module from `module` directory (with renaming), apply your wild fantasy and make a MR. Current code improvements are also welcome.

[To top]

[To top]: #top
