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
function! s:MessageStoreFuncref( messageStoreDirspec )
    if ! has_key(s:funcrefs, a:messageStoreDirspec)
	let s:counter += 1
	let l:functionName = printf('s:MessageStore%d', s:counter)
	execute printf(
	\   "function %s()\n" .
	\   "   return %s . strftime('/message-%%Y%%m%%d_%%H%%M%%S')\n" .
	\   "endfunction",
	\   l:functionName,
	\   string(a:messageStoreDirspec)
	\)
	let s:funcrefs[a:messageStoreDirspec] = s:function(l:functionName)
    endif

    return s:funcrefs[a:messageStoreDirspec]
endfunction

function! s:SetupMappings( messageStoreDirspec, range)
    execute printf('command! -buffer -bang -count=1 -nargs=? -complete=file MessageRecall call MessageRecall#Buffer#Recall(<bang>0, <count>, <q-args>, %s, %s)', string(a:messageStoreDirspec), string(a:range))

    execute printf('nnoremap <silent> <buffer> <C-p> :<C-u>call MessageRecall#Buffer#Replace(1, v:count1, %s, %s)<CR>', string(a:messageStoreDirspec), string(a:range))
    execute printf('nnoremap <silent> <buffer> <C-n> :<C-u>call MessageRecall#Buffer#Replace(0, v:count1, %s, %s)<CR>', string(a:messageStoreDirspec), string(a:range))
endfunction

function! MessageRecall#Setup( messageStoreDirspec, range )
    call BufferPersist#Setup(s:MessageStoreFuncref(a:messageStoreDirspec), a:range)
    call s:SetupMappings(a:messageStoreDirspec, a:range)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
