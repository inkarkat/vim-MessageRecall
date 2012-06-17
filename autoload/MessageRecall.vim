" MessageRecall.vim: Browse and re-insert previous (commit, status) messages.
"
" DEPENDENCIES:
"   - BufferPersist.vim autoload script
"   - MessageRecall/Buffer.vim autoload script
"   - ingofile.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.003	18-Jun-2012	Due to a change in the BufferPersist API, the
"				messageStoreFunction must now take a bufNr
"				argument.
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

    return a:messageStoreDirspec . strftime('/buffer-%Y%m%d_%H%M%S')
endfunction

let s:counter = 0
let s:funcrefs = {}
function! s:function(name)
    return function(substitute(a:name, '^s:', matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$'),''))
endfunction
function! s:GetFuncrefs( messageStoreDirspec )
    if ! has_key(s:funcrefs, a:messageStoreDirspec)
	let s:counter += 1

	let l:messageStoreFunctionName = printf('s:MessageStore%d', s:counter)
	execute printf(
	\   "function %s( bufNr )\n" .
	\   "   return ingofile#CombineToFilespec(%s, strftime('%s'))\n" .
	\   "endfunction",
	\   l:messageStoreFunctionName,
	\   string(a:messageStoreDirspec),
	\   s:messageFilenameTemplate
	\)
	let l:completeFunctionName = printf('<SID>CompleteFunc%d', s:counter)
	execute printf(
	\   "function %s( ArgLead, CmdLine, CursorPos )\n" .
	\   "   return MessageRecall#Buffer#Complete(%s, a:ArgLead)\n" .
	\   "endfunction",
	\   l:completeFunctionName,
	\   string(a:messageStoreDirspec)
	\)
	let s:funcrefs[a:messageStoreDirspec] = [s:function(messageStoreFunctionName), completeFunctionName]
    endif

    return s:funcrefs[a:messageStoreDirspec]
endfunction

function! s:SetupMappings( messageStoreDirspec, range, CompleteFuncref )
    execute printf('command! -buffer -bang -count=1 -nargs=? -complete=customlist,%s MessageRecall  call MessageRecall#Buffer#Recall(<bang>0, <count>, <q-args>, %s, %s)', a:CompleteFuncref, string(a:messageStoreDirspec), string(a:range))
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessagePreview call MessageRecall#Buffer#Preview(<count>, <q-args>, %s, %s)', a:CompleteFuncref, string(a:messageStoreDirspec), string(a:range))

    execute printf('nnoremap <silent> <buffer> <C-p> :<C-u>call MessageRecall#Buffer#Replace(1, v:count1, %s, %s)<CR>', string(a:messageStoreDirspec), string(a:range))
    execute printf('nnoremap <silent> <buffer> <C-n> :<C-u>call MessageRecall#Buffer#Replace(0, v:count1, %s, %s)<CR>', string(a:messageStoreDirspec), string(a:range))
endfunction
let s:autocmds = {}
function! s:SetupAutocmds( messageStoreDirspec )
    " When a stored message is opened via :MessagePreview, settings like
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
function! MessageRecall#Setup( messageStoreDirspec, range )
"******************************************************************************
"* PURPOSE:
"   Set up autocmds for the current buffer to automatically persist the buffer
"   contents within a:range when Vim is done editing the buffer (both when is
"   was saved to a file and also when it was discarded, e.g. via :bdelete!), and
"   corresponding commands and mappings to iterate and recall previously stored
"   mappings.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Writes buffer contents within a:range to a timestamped message file in
"   a:messageStoreDirspec.
"* INPUTS:
"   a:messageStoreDirspec   Storage directory for the messages. The directory
"			    will be created if it doesn't exist yet.
"   a:range A |:range| expression limiting the lines of the buffer that should
"	    be persisted. This can be used to filter away some content. Default
"	    is "", which includes the entire buffer.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if MessageRecall#IsStoredMessage(expand('%'))
	" Avoid recursive setup when a stored message is edited.
	return
    endif

    let [l:MessageStoreFuncref, l:CompleteFuncref] = s:GetFuncrefs(a:messageStoreDirspec)
    call BufferPersist#Setup(l:MessageStoreFuncref, {'range': a:range})
    call s:SetupMappings(a:messageStoreDirspec, a:range, l:CompleteFuncref)
    call s:SetupAutocmds(a:messageStoreDirspec)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
