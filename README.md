MESSAGE RECALL
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

This plugin automatically persists (parts of) buffers used for the editing of
commit (or other) messages, where Vim is invoked as the editor from an
external tool. In these buffers, it sets up mappings and commands to iterate
through stored past messages, and recall the contents for use in the currently
edited message. This way, you automatically collect a history of (committed or
aborted) past messages, and can quickly base your current message on contents
recalled from that history.

### SEE ALSO

This plugin is used by:
- VcsMessageRecall.vim ([vimscript #4117](http://www.vim.org/scripts/script.php?script_id=4117)):
  Browse and re-insert previous VCS commit messages.

USAGE
------------------------------------------------------------------------------

    The plugin is completely inactive until you set it up for a particular
    buffer through the following function; you'll find the details directly in the
    .vim/autoload/MessageRecall.vim implementation file.

    MessageRecall#Setup( messageStoreDirspec, ... )

### INSIDE THE CURRENT MESSAGE BUFFER

    After setup, the following mappings and commands are available in the current
    message buffer:

    CTRL-P, CTRL-N          When the buffer has no unsaved changes: Replace the
                            edited message with a [count]'th previous / next
                            stored message.
                            When the buffer is modified: Open the [count]'th
                            previous / first stored message in the preview window.
                            When the buffer is modified and a stored message is
                            already being previewed: Open the [count]'th previous
                            / next stored message there.

    :[count]MessageView
                            View the [count]'th previous stored message in the
                            preview-window.
    :MessageView {message}|{filespec}
                            View {message} (auto-completed from the message store
                            directory) or any arbitrary {filespec} contents
                            in the preview-window.

    :[count]MessageRecall[!]
                            Insert the [count]'th previous stored message below
                            the current line.
    :MessageRecall[!] {message}|{filespec}
                            Insert {message} (auto-completed from the message
                            store directory) or any arbitrary {filespec} contents
                            below the current line.

                            When the existing message consists of just empty
                            lines (originating from the message template that the
                            tool invoking Vim has put there), the inserted message
                            replaces those empty lines. With [!]: Replace an
                            existing message with the inserted one.

### INSIDE A MESSAGE PREVIEW WINDOW

    CTRL-P, CTRL-N          Go to the previous / next stored message.

    :MessageRecall          Insert the previewed stored message below the current
                            line in the buffer from which the message preview was
                            opened.

### INSIDE BOTH

    :[N]MessageList         Show all / the last [N] messages in the
                            location-list-window; most recent first. (So the
                            line number directly corresponds to {count} in
                            :{count}MessageRecall.)

    :[N]MessageGrep [arguments]
                            Search for [arguments] in all / the last [N] stored
                            messages, and set the location-list to the matches.

    :[N]MessageVimGrep [/]{pattern}[/]
                            Search for {pattern} in all / the last [N] stored
                            messages, and set the location-list to the matches.

    :MessageStore[!] {dirspec}| {identifier}|N
                            Add the directory {dirspec} as a source (with [!]: set
                            as the sole source) for recalled messages.
                            If message stores have been preconfigured (cp.
                            g:MessageRecall_ConfiguredMessageStores), these can
                            be referenced via their short {identifier} instead, or
                            by the N'th last accessed message store .
    :MessageStore           List all message store directories for the current
                            buffer.

    :[N]MessagePrune[!]     Remove all / the oldest [N] messages from the message
                            store, with [!] without confirmation.
    :MessagePrune[!] {fileglob}
                            Remove all files matching {fileglob} from the message
                            store, with [!] without confirmation.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-MessageRecall
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim MessageRecall*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.038 or
  higher.
- Requires the BufferPersist plugin ([vimscript #4115](http://www.vim.org/scripts/script.php?script_id=4115)).

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

When you have multiple, related repositories, you may wish to recall messages
from other message stores. Though this is possible via :MessageRecall
path/to/other/message-store, it is tedious, and you cannot browse / preview
them as easily as the ones from the current message store. For this, you can
define additional message stores via:

    let b:MessageRecall_MessageStores = ['', 'path/to/other/message-store']

The empty string stands for the current message store; by omitting it, its
messages won't be offered any more. Note that this only affects recall and
preview; the edited messages are still exclusively persisted to the current
message store.

If you don't want to directly add more message stores, but enable the user to
quickly do so, you can configure additional message stores together with short
identifying names:

    let g:MessageRecall_ConfiguredMessageStores = {
    \   'repo1': '/path/to/repo1/.svn/commit-msgs',
    \   'repo2': '/path/to/repo2/.git/commit-msgs',
    \]

If you want to use different mappings, first disable the default key mappings
in your vimrc:

    map <Plug>DisableMessageRecallPreviewPrev <Plug>(MessageRecallPreviewPrev)
    map <Plug>DisableMessageRecallPreviewNext <Plug>(MessageRecallPreviewNext)
    map <Plug>DisableMessageRecallGoPrev      <Plug>(MessageRecallGoPrev)
    map <Plug>DisableMessageRecallGoNext      <Plug>(MessageRecallGoNext)

Since there's no common filetype for this plugin, User events are fired for
each message buffer. You can hook into these events to define alternative
mappings:

    autocmd User MessageRecallBuffer  map <buffer> <Leader>P <Plug>(MessageRecallGoPrev)
    autocmd User MessageRecallBuffer  map <buffer> <Leader>N <Plug>(MessageRecallGoNext)
    autocmd User MessageRecallPreview map <buffer> <Leader>P <Plug>(MessageRecallPreviewPrev)
    autocmd User MessageRecallPreview map <buffer> <Leader>N <Plug>(MessageRecallPreviewNext)

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-MessageRecall/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### 1.40    RELEASEME
- ENH: Add a:options.subDirForUserProvidedDirspec so that the user can pass
  the base directory instead of remembering where exactly the messages are
  stored internally.
- ENH: Add a:options.ignorePattern to be able to skip persisting boilerplate
  messages and discard and replace them with a recalled message instead of
  opening in the preview window. Useful e.g. for "Merge branch 'foo'".

##### 1.30    23-Feb-2020
- ENH: Sort the :MessageStore completion candidates for configured message
  stores by last modification time (instead of alphabetically by identifier),
  so stores that were recently updated come first.
- ENH: Allow :MessageStore referencing via N count of configured stores, too.

##### 1.20    18-Nov-2018
- ENH: Add :MessageList, :MessageGrep, and :MessageVimGrep commands.
- ENH: Add :MessagePrune.
- Refactoring.

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.023!__

##### 1.10    23-Dec-2014
- ENH: For :MessageRecall command completion, return the messages from other
  message stores also in reverse order, so that the latest one comes first.
- ENH: Allow to override / extend the message store(s) via
  b:MessageRecall\_MessageStores configuration.
- Get rid of the dependency to the EditSimilar.vim plugin.
- ENH: Add :MessageStore command that allows to add / replace message stores.
  Presets can be configured via the new
  b:MessageRecall\_ConfiguredMessageStores variable.
- Use ingo#compat#glob() and ingo#compat#globpath().

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.022!__
  The dependency to the EditSimilar.vim plugin has been dropped.

##### 1.03    16-Apr-2014
- Adapt to changed EditSimilar.vim interface that returns the success status
  now. Abort on error for own plugin commands.

__You need to update to EditSimilar.vim ([vimscript #2544](http://www.vim.org/scripts/script.php?script_id=2544)) version 2.40!__

##### 1.02    21-Nov-2013
- CHG: Only replace on &lt;C-p&gt; / &lt;C-n&gt; in the message buffer when the considered
  range is just empty lines. I came to dislike the previous replacement also
  when the message had been persisted.
- CHG: On &lt;C-p&gt; / &lt;C-n&gt; in the original message buffer: When the buffer is
  modified and a stored message is already being previewed, change the
  semantics of count to be interpreted relative to the currently previewed
  stored message. Beforehand, one had to use increasing &lt;C-p&gt;, 2&lt;C-p&gt;, 3&lt;C-p&gt;,
  etc. to iterate through stored messages (or go to the preview window and
  invoke the mapping there).
- ENH: Allow to override the default &lt;C-p&gt; / &lt;C-n&gt; mappings.
- Add dependency to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)).

__You need to separately
  install ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.012 (or higher)!__

##### 1.01    12-Jul-2012
- BUG: Script error E486 when replacing a non-matching commit message buffer.

##### 1.00    25-Jun-2012
- First published version.

##### 0.01    09-Jun-2012
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2012-2022 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
