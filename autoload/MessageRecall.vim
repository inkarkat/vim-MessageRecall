" MessageRecall.vim: Browse and re-insert previous (commit, status) messages.
"
" DEPENDENCIES:
"   - BufferPersist.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	002	12-Jun-2012	Split off BufferPersist functionality from
"				the original MessageRecall plugin.
"	001	09-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

let s:pathSeparator = (exists('+shellslash') && ! &shellslash ? '\' : '/')
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
	\   "function %s()\n" .
	\   "   return %s . strftime('%s%s')\n" .
	\   "endfunction",
	\   l:messageStoreFunctionName,
	\   string(a:messageStoreDirspec),
	\   s:pathSeparator,
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

function! MessageRecall#Setup( messageStoreDirspec, range )
    if expand('%:t') =~# substitute(s:messageFilenameTemplate, '%.' , '.*', 'g')
	" Avoid recursive setup when a stored message is edited.
	return
    endif

    let [l:MessageStoreFuncref, l:CompleteFuncref] = s:GetFuncrefs(a:messageStoreDirspec)
    call BufferPersist#Setup(l:MessageStoreFuncref, a:range)
    call s:SetupMappings(a:messageStoreDirspec, a:range, l:CompleteFuncref)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
