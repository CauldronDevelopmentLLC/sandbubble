# sandbubble
Simplifies the use of [bubblewrap](https://github.com/containers/bubblewrap)
and [xdg-dbus-proxy](https://github.com/flatpak/xdg-dbus-proxy) to sandbox
applications in Linux.

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

Based on
[code by Simon Lipp](https://gist.github.com/sloonz/4b7f5f575a96b6fe338534dbc2480a5d).  See
[Simon's blog post](https://sloonz.github.io/posts/sandboxing-3/) for more
information.

# Quickstart

Copy ``sandbubble.yml`` to ``~/.config`` and edit to suit your needs.

Create and enter a sandbox follows:

    sandbubble <name> <executable> <args>

This will create a sandbox at ``$HOME/sandboxes/<name>``.

Sandbubble remembers your settings so you can rerun the same sandbox like
this:

    sandbubble <name>

You can edit the config in ``$HOME/sandboxes/<name>/.config/sandbubble.yml`` to change how the sandbox runs.

To delete a sandbox:

    rm -rf sandboxes/<name>

# Command line options

To see the command line options run:

    sandbubble --help

# Configuration

Sandbubble uses a [YAML](https://yaml.org/) configuration file.  There are two top level keys ``rules`` and ``defaults``.

## Rules
Under the ``rules`` key are arbitrary named sets of rules.  For example,
a configuration which does nothing but has two rules ``a`` and ``b`` would look like this:

```yaml
rules:
  a:
  b:
```

Rule names are referenced by the ``use`` rule or the ``use`` default.

### String variable replacement

Parameter strings in rules may contain variable references that are replaced
using Python 3 string format syntax.  Valid replacement variables are as follows:

- ``env[<name>]``
  Replaced with an environment variable.

- ``name``
  Replaced with the name of the sandbox.

- ``pid``
  Replaced with the process ID.

Example:

```yaml
rules:
  private-home:
    - bind:
        path: '{env[HOME]}/sandboxes/{name}/'
        dst: '{env[HOME]}'
        read-write: true
        create: skel
    - dir: '{env[HOME]}/.config'
    - dir: '{env[HOME]}/.cache'
    - dir: '{env[HOME]}/.local/share'
```

The above rule creates a private home directory with several subdirectries.

### ``args: [<arg>...]``
A list of arbitrary additional arguments to pass to ``bwrap``.

```yaml
rules:
  common:
    - args: [--clearenv, --unshare-pid, --die-with-parent, --proc, /proc,
        --dev, /dev, --tmpfs, /tmp]
```

### ``bind: {...}``
May be a simple string in which case it describes a path to bind in read-only
mode.  E.g.:

```yaml
rules:
  x11:
    - bind: /tmp/.X11-unix/
```

Or it may be a dictionary with the following optional keys:

- ``path: <string>`` (required)
  The source path to bind.  Also the destination if ``dst`` is not specified.

- ``dst: <string>``
  The destination path to bind.

- ``read-write: <bool>``
  If true the bind will be writeable.

- ``create: <bool> | 'skel'``
  If true the destination directory will be created if it does not already
  exist.

  If the special value `skel` is specified then the contents of
  ``/etc/skel`` will be copied to the destination directory when it is first
  created.  This is useful to setup a new default home directory.  Note,
  if ``.bashrc`` exists in ``/etc/skel`` the name of the sandbox will be added
  to the command prompt.

- ``try: <bool>``
  If true and the source directory does not exist then the bind will quietly
  be ignored.

- ``cwd: <bool>``
  If true the current directory will be taken as the source path.

### ``chdir: <path>``
Change directories inside the sandbox.

```yaml
rules:
  example:
    - bind: '{env[HOME]}/tmp'
    - chdir: '{env[HOME]}/tmp'
```

### ``dbus: {...}``

Parameters are:

- ``system: <bool>``
  Use the system dbus rather than the session dbus.

- ``allow: <type> | [<type>...]``
  Where <type> is one of 'see', 'talk', 'own', 'call' or 'broadcast'
  See ``bwrap`` documentation.

- ``path: <string>``
  A dbus path.

### ``dir: <path>``
Create a directory.  Takes a single string parameter.

```yaml
rules:
  example:
    - dir: '{env[HOME]}/example'
```

### ``file: [<data>, <dst>]``
Copy the specified ``<data>`` to the target file ``<dst>``.

```yaml
rules:
  example:
    - file: ['Hello World!', 'hello.txt']
```

### ``restrict_tty``
Restricts access to the calling terminal to prevent CVE-2017-5226.

### ``env: [<name>...] | {<name>: <value>...}``
Set environment variables.  Either a list of variables to define empty or
a dictionary of name values pairs.

```yaml
rules:
  example:
    - env: {PATH: /usr/bin:/bin}
    - env: [LANG, TERM, HOME, LOGNAME, USER]
```

### ``symlink: [<src>, <dst>]``
Create a symlink.

```yaml
rules:
  example:
    - symlink: [usr/bin, /bin]
```

### ``use: [<rule1>, <rule2>, ...]``
Apply the named rules.

```yaml
rules:
  a:
    - use: b, c
  b:
  c:
```

## Defaults

The ``defaults`` section contains default options.  When a sandbox is created
the ``defaults`` section is created in it's own ``sandbubble.yml`` file
recording the command run and which rules were used.

```yaml
defaults:
  use: [common, private-home, x11, pulseaudio, portal, accessibility]
  command: [bash]
```

### ``use: [<rule1>, <rule2>, ...]``
A list of rules to apply.

### ``command: [<command>, <arg1>, ...]``
The command to run.
