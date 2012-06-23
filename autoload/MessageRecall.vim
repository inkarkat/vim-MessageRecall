" MessageRecall.vim: Browse and re-insert previous (commit, status) messages.
"
" DEPENDENCIES:
"   - BufferPersist.vim autoload script
"   - MessageRecall/Buffer.vim autoload script
"   - MessageRecall/MappingsAndCommands.vim autoload script
"   - ingofile.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.005	20-Jun-2012	Change API to pass optional a:options, like
"				BufferPersist does. Right now all options are
"				forwarded to it, anyway.
"   1.00.004	19-Jun-2012	Rename :MessagePreview to :MessageView, as the
"				former hints at previewing the current commit
"				message, not viewing older messages.
"				Extract mapping and command setup to
"				MessagRecall/MappingsAndCommands.vim.
"   1.00.003	18-Jun-2012	Due to a change in the BufferPersist API, the
"				messageStoreFunction must now take a bufNr
"				argument.
"				FIX: Actually use MessageRecall#MessageStore().
"	002	12-Jun-2012	Split off BufferPersist functionality from
"				the original MessageRecall plugin.
"	001	09-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

let s:messageFilenameTemplate = 'message-%Y%m%d_%H%M%S'
let s:messageFilenameGlob = 'message-*'
function! MessageRecall#Glob()
    return s:messageFilenameGlob
endfunction

function! MessageRecall#MessageStore( messageStoreDirspec )
    if exists('*mkdir') && ! isdirectory(a:messageStoreDirspec)
	" Create the message store directory in case it doesn't exist yet.
	call mkdir(a:messageStoreDirspec, 'p', 0700)
    endif

    return ingofile#CombineToFilespec(a:messageStoreDirspec, strftime(s:messageFilenameTemplate))
endfunction

let s:counter = 0
let s:funcrefs = {}
function! s:function(name)
    return substitute(a:name, '^s:', matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$'),'')
endfunction
function! MessageRecall#GetFuncrefs( messageStoreDirspec )
    if ! has_key(s:funcrefs, a:messageStoreDirspec)
	let s:counter += 1

	let l:messageStoreFunctionName = printf('s:MessageStore%d', s:counter)
	execute printf(
	\   "function %s( bufNr )\n" .
	\   "   return MessageRecall#MessageStore(%s)\n" .
	\   "endfunction",
	\   l:messageStoreFunctionName,
	\   string(a:messageStoreDirspec)
	\)
	let l:completeFunctionName = printf('s:CompleteFunc%d', s:counter)
	execute printf(
	\   "function %s( ArgLead, CmdLine, CursorPos )\n" .
	\   "   return MessageRecall#Buffer#Complete(%s, a:ArgLead)\n" .
	\   "endfunction",
	\   l:completeFunctionName,
	\   string(a:messageStoreDirspec)
	\)
	let s:funcrefs[a:messageStoreDirspec] = [function(s:function(messageStoreFunctionName)), s:function(completeFunctionName)]
    endif

    return s:funcrefs[a:messageStoreDirspec]
endfunction

let s:autocmds = {}
function! s:SetupAutocmds( messageStoreDirspec )
    " When a stored message is opened via :MessageView, settings like
    " filetype and the setup of the mappings and commands is handled
    " by the command itself. But when a stored message is opened through other
    " means (like from the quickfix list, or explicitly via :edit), they are
    " not. We can identify the stored messages through their location in the
    " message store directory, so let's set up an autocmd (once for every set up
    " message store).
    if ! has_key(s:autocmds, a:messageStoreDirspec)
	augroup MessageRecall
	    execute printf('autocmd BufRead %s %s',
	    \   ingofile#CombineToFilespec(a:messageStoreDirspec, MessageRecall#Glob()),
	    \   MessageRecall#Buffer#GetPreviewCommands(-1, &l:filetype)
	    \)
	augroup END

	let s:autocmds[a:messageStoreDirspec] = 1
    endif
endfunction

function! MessageRecall#IsStoredMessage( filespec )
    return fnamemodify(a:filespec, ':t') =~# substitute(s:messageFilenameTemplate, '%.' , '.*', 'g')
endfunction
function! MessageRecall#Setup( messageStoreDirspec, ... )
"******************************************************************************
"* PURPOSE:
"   Set up autocmds for the current buffer to automatically persist the buffer
"   contents within a:options.range when Vim is done editing the buffer (both
"   when is was saved to a file and also when it was discarded, e.g. via
"   :bdelete!), and corresponding commands and mappings to iterate and recall
"   previously stored mappings.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Writes buffer contents within a:options.range to a timestamped message file
"   in a:messageStoreDirspec.
"* INPUTS:
"   a:messageStoreDirspec   Storage directory for the messages. The directory
"			    will be created if it doesn't exist yet.
"   a:options               Optional Dictionary with configuration:
"   a:options.range         A |:range| expression limiting the lines of the
"			    buffer that should be persisted. This can be used to
"			    filter away some content. Default is "", which
"			    includes the entire buffer.
"   a:options.whenRangeNoMatch  Specifies the behavior when a:options.range
"				doesn't match. One of:
"				"error": an error message is printed and the
"				buffer contents are not persisted
"				"ignore": the buffer contents silently are not
"				persisted
"				"all": the entire buffer is persisted instead
"* RETURN VALUES:
"   None.
"******************************************************************************
    if MessageRecall#IsStoredMessage(expand('%'))
	" Avoid recursive setup when a stored message is edited.
	return
    endif

    let l:messageStoreDirspec = ingofile#NormalizePathSeparators(a:messageStoreDirspec)
    let [l:MessageStoreFuncref, l:CompleteFuncref] = MessageRecall#GetFuncrefs(l:messageStoreDirspec)

    let l:options = (a:0 ? a:1 : {})
    call BufferPersist#Setup(l:MessageStoreFuncref, l:options)

    let l:range = get(l:options, 'range', '')
    call MessageRecall#MappingsAndCommands#MessageBufferSetup(l:messageStoreDirspec, l:range, l:CompleteFuncref)
    call s:SetupAutocmds(l:messageStoreDirspec)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
