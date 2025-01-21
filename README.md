# Sandbubble

A tool for easily sandboxing applications in Linux.

Linux is generally considered a secure operating system.  However, when you
run a program that program is by default given the same access as your user.
Malicious software can easily install something bad in your user start up
scripts or steal data such as the private keys stored in ``~/.ssh``, make a
copy of your crypto wallet or steal your browsing history.  This risk might
be acceptable for the packages provided by your operating system.  Presumably
these have been vetted.  However, if you run tools like ``npm``,
``pip`` or ``vscode`` which pull arbitrary code from hundreds of different
sources and run them with full access to all your personal files, that's
another story.  Sandbubble aims to solve this problem by making it easier to
sandbox applications and give them only the access they require to operate.

Sandbubble uses [bubblewrap](https://github.com/containers/bubblewrap)
and [xdg-dbus-proxy](https://github.com/flatpak/xdg-dbus-proxy) to sandbox
applications in Linux.  Based on
[code by Simon Lipp](https://gist.github.com/sloonz/4b7f5f575a96b6fe338534dbc2480a5d).  See
[Simon's blog post](https://sloonz.github.io/posts/sandboxing-3/) for more
information.

# Install

First install the required packages.  On Debian run:

    sudo apt-get install -y python3 bubblewrap xdg-dbus-proxy

Then, following manual install is recommended:

```sh
mkdir -p ~/.config/sandbubble
cp global.yml ~/.config/sandbubble
mkdir -p ~/.local/bin
cp sbx ~/.local/bin
```

Make sure ``~/.local/bin`` is on your path.  Perhaps by adding the following
line to your ``~/.bashrc`` file:

```sh
export PATH=$HOME/.local/bin:$PATH
```

# Quickstart

Create a new sandbox:

    sbx create <name> <executable> <args>...

You can edit the sandbox config with:

    sbx edit <name>

Note, editing requires that the ``EDITOR`` environment variable is set
correctly.

Finally, run your sandbox:

    sbx run <name> <args>...

# Example (sandboxing npm)

Create a sandbox for ``npm``:

    sbx create npm -r cli npm

The first ``npm`` is the name of the new sandbox.  ``-r cli`` applies the
rule for command line programs.  The second ``npm`` is the command to run.

Now you can run sandboxed ``npm`` to build a project in the current directory:

    sbx run npm run build

Note that if you want to pass any argument starting with ``-`` to your sandbox
and not to ``sbx`` then you will need to add ``--`` like this:

    sbx run npm -- --help

# Command line
Sandbubble's executable is called ``sbx``.  It takes one of the following
subcommands:

    create       create a new sandbox
    reconfig     reconfigure an existing sandbox
    run          run an existing sandbox
    list         list existing sandboxes
    list-rules   list available rules
    delete       delete an existing sandbox
    show         print sandbox config and exit
    edit         edit sandbox config
    help         show this help message and exit

To see the help for a subcommand run:

    sbx <subcommand> --help

# Configuration

Sandbubble uses a [YAML](https://yaml.org/) configuration file.  A config
consists of a top-level dictionary containing up to 4 keys, as follows:

- ``use``     - A list of rules to use by default.
- ``command`` - A list containing the default command and any arguments.
- ``imports`` - A list of paths to other configs to import rules from.
- ``rules``   - A dictionary containing all the applicable rules.

For example:

```yaml
use: [gui, gpu]
command: [java, -jar, Mindustry.jar]
imports: [$HOME/.config/sandbubble/global.yml]
```

The above is a complete config for a sandbox that runs the game
[Mindustry](https://mindustrygame.github.io/).  The jar file must be placed
in the sandbox's home directory and Java must be installed on the host system.
The ``gui`` rule allows access to the Graphical User Interface and the
``gpu`` rule access to the GPU.

## Variable replacement

Parameter strings in a config may contain environment variable references
like ``$NAME`` or ``${NAME}``.

Example:

```yaml
rules:
  private-home:
    - bind:
        path: $SANDBOX_HOME
        dst: $HOME
        read-write: true
        create: skel
    - dir: $HOME/.config
    - dir: $HOME/.cache
    - dir: $HOME.local/share
```

The above rule creates a private home directory with several subdirectories.

You may also use ``~`` instead of ``$HOME``.

A few environment variables are defined by Sandbubble itself these are:

- ``SANDBOX``        - The name of the current sandbox.
- ``SANDBOX_HOME``   - A home directory for the sandbox.
- ``SANDBOX_CONFIG`` - The path to the sandbox's config file.
- ``SANDBOX_ROOT``   - Sandbubble's root config directory.

Note, these variables may be used in configs but are not automatically passed
to the sandboxed process.

## Key: ``use: [<rule1>, <rule2>, ...]``

When ``use`` is specified at the top level of the sandbox config file, the
rules it lists will be applied unless ``-r <rule>`` is passed.  ``use`` is
first set when the sandbox is created.

For example:

```yaml
use: [gui, gpu, downloads]
```

## Key: ``command: [<command>, <arg1>, ...]``

When ``command`` is specified at the top level of a sandbox config it
specifies the command to run in the sandbox and its arguments.

When ``command`` is specified in Sandbubble's global config file it specifies
the default command and arguments to apply to new sandboxes.

## Key: ``imports: [<path>...]``

Imports may be relative or absolute paths.  Paths are interpreted relative
to the importing file.

Imported rules override previously imported rules.  However, the rules in
the config doing the importing take precedence over the imported rules.

## Key: ``rules: {...}``

Under the ``rules`` key are arbitrary named rules containing lists of
configuration actions.  If the first item in a rule's list is a string
it is the rule's help which you can see with ``sbx list-rules``.

For example, a simple config with two rules that runs
``bash`` and binds three read-only directories could look like this:

```yaml
use: [bin, lib]
command: [bash]
rules:
  bin:
    - Binds the /bin and /usr/bin directories read-only.
    - bind: /bin
    - bind: /usr/bin
  lib:
    - Binds the /lib directory read-only.
    - bind: /lib
```

Rules are referenced by name with the ``use`` top-level key or a ``use``
action.

Of course, the above example is not very useful.  You need more
complicated rules in most cases.  Many useful rules are already defined in
``global.yml``.

### Action: ``args: [<arg>...]``
A list of arbitrary additional arguments to pass to ``bwrap``.

Example:
```yaml
rules:
  common:
    - args: [--clearenv, --unshare-pid, --die-with-parent]
```

### Action: ``bind: {...}``
The argument to bind may be a simple string in which case it describes a path
to bind in read-only mode.

Example:
```yaml
rules:
  x11:
    - bind: /tmp/.X11-unix/
```

Or it may be a dictionary with the following optional keys:

- ``path: <string>``
  The source path to bind.  Also the destination if ``dst`` is not specified.

- ``dst: <string>``
  The destination path to bind.  Defaults to the same path as the source.

- ``read-write: <bool>``
  If true the bind will be writeable, otherwise it's read-only.

- ``create: <bool> | 'skel'``
  If true, the destination directory will be created if it does not already
  exist.

  If the special value `skel` is specified then the contents of
  ``/etc/skel`` will be copied to the destination directory when it is first
  created.  This is useful to setup a new sandbox home directory.  Note,
  if ``.bashrc`` exists in ``/etc/skel`` the name of the sandbox will be added
  to the command prompt.

- ``try: <bool>``
  If true and the source directory does not exist then the bind will quietly
  be ignored.

- ``cwd: <bool>``
  If true the current directory will be taken as the source path.

### Action: ``chdir: <path>``
Change directories inside the sandbox.

Example:
```yaml
rules:
  example:
    - bind: $HOME/tmp
    - chdir: $HOME/tmp
```

### Action: ``dbus: {...}``

Parameters are:

- ``system: <bool>``
  Use the system dbus rather than the session dbus.

- ``allow: <type> | [<type>...]``
  Where ``<type>`` is one of ``see``, ``talk``, ``own``, ``call`` or
  ``broadcast``.  See ``man bwrap``.

- ``path: <string>``
  A dbus path.  See ``man xdg-dbus-proxy``.

### Action: ``del-arg: [<pattern>...]``
Delete an argument previously added to ``bwrap`` by another rule.  If a
series of arguments match all of the provided patterns then those arguments
will be removed from the ``bwrap`` command line.  Patterns may be regular
expressions.

Example:
```yaml
rules:
  example:
    - del-arg: [--die-with-parent]
```

### Action: ``dev: <path> | {path: <path>, perms: <perms>}``
Create a dev file system at the specified path.  See ``tmpfs``.

### Action: ``dir: <path> | {path: <path>, perms: <perms>}``
Create a directory inside the sandbox.

Example:
```yaml
rules:
  example:
    - dir: $HOME/example
```

### Action: ``env: [<name>...] | {<name>: <value>...}``
Set environment variables.  Either a list of variables to copy from the
parent environment, if they exist, or a dictionary of name-value pairs.

Note, variables are set in the sandbox's environment and so are not available
to reference (e.g. ``$NAME``) in configs.

Example:
```yaml
rules:
  example:
    - env: {PATH: /usr/bin:/bin}
    - env: [LANG, TERM, HOME, LOGNAME, USER]
```

The above example sets the ``PATH`` and then copies the other variables from
the parent environment to the sandbox's environment.

### Action: ``file: <path> | {data: <data>, path: <path>, perms: <perms>``
Copy the specified ``<data>`` to the target file ``<path>`` in the sandbox.
If just a path is specified, an empty file is created.

Example:
```yaml
rules:
  example:
    - file: ['Hello World!', 'hello.txt']
```

### Action: ``ifdef: [<var>, <action>...]``
If the specified environment variable is set apply the actions.

Example:
```yaml
rules:
  example:
    - ifdef: [WITH_DOWNLOADS, {use: downloads}]

  downloads:
    - bind: {path: $HOME/Downloads, read-write: true}
```

The above example applies the ``downloads`` rule if ``WITH_DOWNLOADS`` is
set in the parent environment.

### Action: ``ifeq: [<value1>, <value2>, <action>...]``
If after variable replacement the two values are equal then apply the actions.

### Action: ``ifneq: [<value1>, <value2>, <action>...]``
If after variable replacement the two values are not equal then apply the
actions.

### Action: ``proc: <path> | {path: <path>, perms: <perms>}``
Create a proc file system at the specified path.  See ``tmpfs``.

### Action: ``restrict_tty:``
Restrict access to the calling terminal to prevent CVE-2017-5226.

### Action: ``symlink: [<src>, <dst>]``
Create a symlink.

Example:
```yaml
rules:
  example:
    - symlink: [usr/bin, /bin]
```

### Action: ``tmpfs: <path> | {path: <path>, size: <size>, perms: <perms>}``
Create a tmp file system at the specified path.  Optionally, specify the
size in bytes and permissions.  Permissions are numerical and usually specified in octal.

Example:
```yaml
rules:
  example:
    - tmpfs:
      path: /tmp
      size: 10485760
      perms: 0o700
```

### Action: ``use: [<rule1>, <rule2>, ...]``
Apply the named rules.

Example:
```yaml
use: [a]
rules:
  a:
    - use: b, c
  b:
  c:
```
