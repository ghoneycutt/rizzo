#! /bin/bash
#
# Test to ensure the gem actually builds.  Pre-requisite step to verify the gem
# installs.  Run this script from the repository root.
# can

# Turn off validation for testing purposes.  We'll turn it back on for explicit
# testing of the validation behavior
export RZO_VALIDATE='false'

set -eu

STAMP=$(date +%s)

if [[ -z "${NO_COLOR:-}" ]]; then
  NC='\033[0m' # No Color
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
else
  NC=''
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
fi

# Describe the test with a nice heading
desc() {
  msg="$1"
  echo
  echo -e "${GREEN}${msg}${NC}"
  echo "${msg//?/=}"
  return 0
}

testcase() {
  msg="$1"
  echo -en "  * ${NC}${msg}:${NC} "
  return 0
}

# Look for a string in some output, e.g. stderr or stdout.
match() {
  msg="$1"      # descriptive message
  expected="$2" # a file
  actual="$3"   # extended regexp
  testcase "$msg"
  if grep -qE "$expected" "$actual"; then
    pass "It does."
    return 0
  else
    echo "Expected $actual to contain '${expected}', but it did not." >&2
    echo "Expected:"
    cat "$expected"
    echo
    echo "Actual:"
    cat "$actual"
    fail "Did not find '$expected' in $actual"
    return 1
  fi
}

pass() {
  msg="$1"
  echo -e "${GREEN}PASS:${NC} ${msg}" >&2
  return 0
}

fail() {
  msg="$1"
  echo -e "${RED}FAIL:${NC} $msg" >&2
  return 1
}

warn() {
  msg="$1"
  echo -e "${YELLOW}Warning:${NC} $msg" >&2
}

err() {
  msg="$1"
  echo -e "${RED}Error:${NC} $msg" >&2
}

debug() {
  [[ -z "${DEBUG:-}" ]] && return 0
  msg="$1"
  echo -e "${BLUE}Debug:${NC} $msg" >&2
}

# Move ~/.rizzo.json out of the way if it exists
if [[ -e ~/.rizzo.json ]]; then
  debug "Moving ~/.rizzo.json to ~/.rizzo.json.$STAMP"
  mv -f ~/.rizzo.json ~/.rizzo.json.$STAMP
fi

# Clean up our temp directory
scratch=$(mktemp -d)
export TMPDIR="$scratch"
finish() {
  if [[ -e ~/.rizzo.json.$STAMP ]]; then
    mv -f ~/.rizzo.json.$STAMP ~/.rizzo.json
    debug "Moved ~/.rizzo.json.$STAMP to ~/.rizzo.json"
  fi
  if [[ -d "$scratch" ]]; then
    rm -rf "$scratch"
    debug "Removed $scratch"
  fi
}
trap finish EXIT

[ -d pkg ] && rm -rf pkg
mkdir pkg
bundle exec rake build

# Load RVM into a shell session *as a function*.  This is necessary to switch
# gemsets.  This script should still operate without rvm, but it would pollute
# GEM_HOME, so must be explicitly enabled by the user using RZO_GEM_INSTALL
for i in "$HOME/.rvm/scripts/rvm" "/usr/local/rvm/scripts/rvm"; do
  if [[ -s "$i" ]]; then
    set +u # RVM uses unbound variables, which makes me very sad. :(
    source "$i"
    RZO_GEM_INSTALL=yes
    break
  fi
done

# We use a custom gemset to ensure the build dependency bundle is isolated from
# the functional testing phase.
if [[ -z ${RZO_GEM_INSTALL:-} ]]; then
  warn "rvm not found, GEM_HOME will be tainted by the tests."
  warn "To proceed anyway, run: INSTALL_TO_GEM_HOME=true $0"
  [[ -z ${INSTALL_TO_GEM_HOME:-} ]] && exit 1
else
  rvm gemset create cleanroom
  rvm gemset use cleanroom
fi

desc "The gem environment used for functional testing"
gem env

desc "There should be minimal gems installed initially"
gem list

desc "Install the gem"
gem install pkg/*.gem

desc "The gem and dependencies should be installed"
gem list

desc "The executable should be in the path"
which rzo

desc "rzo --help should contain usage"
stdout=$(mktemp -t XXXXXX.stdout)
rzo --help | tee $stdout
expected='usage: .*GLOBAL OPTIONS.*SUBCOMMAND.*ARGS'
if ! grep -qE "$expected" $stdout; then
  fail "rzo --help STDOUT does not contain '$expected'"
fi

desc "rzo --version should output a semantic version string"
stdout=$(mktemp -t XXXXXX.stdout)
rzo --version | tee $stdout
grep -qE '[0-9]+\.[0-9]+\.[0-9]' $stdout

desc "rzo bare (no arguments) should match --help"
bare_output=$(mktemp -t XXXXXX.rzo_bare)
help_output=$(mktemp -t XXXXXX.rzo_help)
rzo > $bare_output
rzo --help > $help_output
if diff -U2 $help_output $bare_output; then
  pass "It does."
else
  fail "rzo is not the same as rzo --help"
fi

desc "rzo config with no config should be helpful"
stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
rzo config 2> $stderr | tee $stdout
expected="Cannot read config file"
if ! grep -E "$expected" $stderr; then
  echo "STDERR:"
  cat $stderr >&2
  fail "rzo config STDERR does not contain '$expected'"
else
  pass "Looks good."
fi

# Puppet data repositories used by rizzo
PUPPETDATA="${TMPDIR}/git/puppetdata"

desc "With a valid ~/.rizzo.json file looking like:"
cat > ~/.rizzo.json <<EOCONFIG
{
  "defaults": { "bootstrap_repo_path": "${HOME}/git/bootstrap" },
  "control_repos": [ "${PUPPETDATA}", "${HOME}/git/ghoneycutt-modules" ],
  "puppetmaster": {
    "name": [ "puppetca", "puppet" ],
    "modulepath": [ "./modules", "./puppetdata/modules", "./ghoneycutt/modules" ],
    "synced_folders": {
      "/repos/puppetdata": { "local": "${PUPPETDATA}", "owner": "root", "group": "root" },
      "/repos/ghoneycutt": { "local": "${HOME}/git/ghoneycutt-modules", "owner": "root", "group": "root" }
    }
  }
}
EOCONFIG
# Print out the config
expected=$(mktemp -t XXXXXX.rizzo.json)
ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse(ARGF.read))' ~/.rizzo.json | tee $expected

desc "rzo config is expected to pretty generate the JSON config"
stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
rzo config > $stdout 2> $stderr
if diff -U2 $expected $stdout; then
  pass "It does."
else
  fail "rzo config STDOUT differs from expected pretty generated config"
fi

desc "rzo generate produces a minimal Vagrantfile"

expected=$(mktemp -t XXXXXXX.vagrantfile)
actual=$(mktemp -t XXXXXXX.vagrantfile)
# NOTE: The first line is omitted because it contains a timestamp
cat > $expected <<VAGRANTFILE
# https://github.com/ghoneycutt/rizzo
Vagrant.configure(2) do |config|
  # use 'vagrant plugin install vagrant-proxyconf' to install
  if Vagrant.has_plugin?('vagrant-proxyconf')
    config.proxy.http  = ENV['HTTP_PROXY']  if ENV['HTTP_PROXY']
    config.proxy.https = ENV['HTTPS_PROXY'] if ENV['HTTPS_PROXY']
  end
end
# -*- mode: ruby -*-
# vim:ft=ruby
VAGRANTFILE

stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
rzo generate 2> $stderr
tail -n+2 Vagrantfile > $actual
if diff -U2 $expected $actual; then
  pass "It does."
else
  fail "rzo generate produced a Vagrantfile different than expected"
fi

expected="Wrote vagrant config to Vagrantfile"
desc "rzo generate STDERR is expected to match '$expected'"
if ! grep -qE "$expected" $stderr; then
  echo "Expected:"
  echo "$expected"
  echo
  echo "Actual:"
  cat $stderr
  echo
  fail "Expected STDOUT of rzo generate does not match actual output"
else
  pass "It does."
fi

desc "rzo roles with no personal .rizzo.json is expected to warn"
stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
rzo roles 2> $stderr > $stdout

match "warns about puppetdata not being a directory" 'WARN .*puppetdata is not a directory' $stderr
match "warns about ghoneycutt-modules not being a directory" 'WARN .*ghoneycutt-modules is not a directory' $stderr
match "warns about bootstrap not being a directory" 'WARN .*bootstrap is not a directory' $stderr

desc "with a single puppetca role, rzo roles outputs the role name"
if ! [[ -d "$PUPPETDATA" ]]; then
  mkdir -p "$PUPPETDATA"
  debug "Created $PUPPETDATA"
fi
echo '{"nodes":[{"name":"puppetca"}]}' > ${PUPPETDATA}/.rizzo.json

stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
rzo roles 2> $stderr > $stdout
expected='puppetca'
if grep -qxE "$expected" $stdout; then
  pass "rzo roles STDOUT, expected: '$expected' got: '$(cat $stdout)'"
else
  fail "rzo roles STDOUT, expected: '$expected' got: '$(cat $stdout)'"
fi

desc "rzo generate is expected to produce a Vagrantfile with one VM defined"
expected=$(mktemp -t XXXXXX.vagrantfile.expected)
stdout=$(mktemp -t XXXXXX.stdout)
stderr=$(mktemp -t XXXXXX.stderr)
cat <<VAGRANTFILE > $expected
# https://github.com/ghoneycutt/rizzo
Vagrant.configure(2) do |config|
  # use 'vagrant plugin install vagrant-proxyconf' to install
  if Vagrant.has_plugin?('vagrant-proxyconf')
    config.proxy.http  = ENV['HTTP_PROXY']  if ENV['HTTP_PROXY']
    config.proxy.https = ENV['HTTPS_PROXY'] if ENV['HTTPS_PROXY']
  end

  config.vm.define "puppetca", autostart: false do |cfg|
    cfg.vm.box = nil
    cfg.vm.box_url = nil
    cfg.vm.box_download_checksum = nil
    cfg.vm.box_download_checksum_type = nil
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', nil]
    end
    cfg.vm.hostname = nil
    cfg.vm.network 'private_network',
      ip: nil,
      netmask: nil
    cfg.vm.synced_folder "${PUPPETDATA}", "/repos/puppetdata",
      owner: "root", group: "root"
    cfg.vm.synced_folder "${HOME}/git/ghoneycutt-modules", "/repos/ghoneycutt",
      owner: "root", group: "root"
    config.vm.synced_folder "${HOME}/git/bootstrap",
      nil,
      owner: 'vagrant', group: 'root'
    config.vm.provision 'shell', inline: "echo 'modulepath = ./modules:./puppetdata/modules:./ghoneycutt/modules' > /environment.conf"
    config.vm.provision 'shell', inline: "/bin/bash / "
  end
end
# -*- mode: ruby -*-
# vim:ft=ruby
VAGRANTFILE
rzo generate 2> $stderr > $stdout
actual=$(mktemp -t XXXXXX.vagrantfile.actual)
tail -n+2 Vagrantfile > $actual
if diff -U2 $expected $actual; then
  cat Vagrantfile
  pass "It does."
else
  fail "actual Vagrantfile does not match expected file"
fi

desc "END of functional testing"
pass "Functional testing completed successfully."
