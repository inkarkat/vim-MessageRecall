" MessageRecall.vim: Browse and re-insert previous (commit, status) messages.
"
" DEPENDENCIES:
"   - BufferPersist.vim plugin
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2022 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

let s:messageFilenameTemplate = 'msg-%Y%m%d_%H%M%S'
let s:messageFilenameGlob = 'msg-*'
function! MessageRecall#Glob()
    return s:messageFilenameGlob
endfunction

function! MessageRecall#MessageStore( messageStoreDirspec )
    if exists('*mkdir') && ! isdirectory(a:messageStoreDirspec)
	" Create the message store directory in case it doesn't exist yet.
	call mkdir(a:messageStoreDirspec, 'p', 0700)
    endif

    return ingo#fs#path#Combine(a:messageStoreDirspec, strftime(s:messageFilenameTemplate))
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
	let s:funcrefs[a:messageStoreDirspec] = [function(s:function(l:messageStoreFunctionName)), s:function(l:completeFunctionName)]
    endif

    return s:funcrefs[a:messageStoreDirspec]
endfunction

let s:autocmds = {}
function! s:SetupAutocmds( messageStoreDirspec, subDirForUserProvidedDirspec )
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
	    \   ingo#fs#path#Combine(a:messageStoreDirspec, MessageRecall#Glob()),
	    \   MessageRecall#Buffer#GetPreviewCommands(-1, &l:filetype, a:subDirForUserProvidedDirspec)
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
"				Default is "error"
"   a:options.ignorePattern If the (joined) text in the persisted range / buffer
"                           matches the pattern, it is treated as if empty and
"                           not persisted.
"   a:options.replacedMessageRegister
"                           If the current message buffer's edited message is
"                           replaced by a previous / next stored message, save
"                           it in the passed register; it is not saved by
"                           default or when it is empty.
"   a:options.subDirForUserProvidedDirspec
"                           Try {dirspec}/{subDirForUserProvidedDirspec} when
"                           the user executes :MessageStore {dirspec} (before
"                           falling back to {dirspec}, so that the user can pass
"                           the base directory instead of remembering where
"                           exactly the messages are stored internally.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if MessageRecall#IsStoredMessage(expand('%'))
	" Avoid recursive setup when a stored message is edited.
	return
    endif

    let l:messageStoreDirspec = ingo#fs#path#Normalize(a:messageStoreDirspec)
    let [l:MessageStoreFuncref, l:CompleteFuncref] = MessageRecall#GetFuncrefs(l:messageStoreDirspec)

    let l:options = (a:0 ? a:1 : {})
    call BufferPersist#Setup(l:MessageStoreFuncref, l:options)

    let l:range = get(l:options, 'range', '')
    let l:whenRangeNoMatch = get(l:options, 'whenRangeNoMatch', 'error')
    let l:subDirForUserProvidedDirspec = get(l:options, 'subDirForUserProvidedDirspec', '')
    let l:ignorePattern = get(l:options, 'ignorePattern', '')
    let l:replacedMessageRegister = get(l:options, 'replacedMessageRegister', '')
    call MessageRecall#MappingsAndCommands#MessageBufferSetup(l:messageStoreDirspec, l:range, l:whenRangeNoMatch, l:ignorePattern, l:replacedMessageRegister, l:subDirForUserProvidedDirspec, l:CompleteFuncref)
    call s:SetupAutocmds(l:messageStoreDirspec, l:subDirForUserProvidedDirspec)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
