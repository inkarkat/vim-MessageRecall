" MessageRecall.vim: Browse and re-insert previous (commit, status) messages.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	09-Jun-2012	file creation

function! MessageRecall#RecordMessage( range, pendingMessageFilespec )
    try
	execute 'silent keepalt' a:range . 'write!' escapings#fnameescape(a:pendingMessageFilespec)
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endtry
endfunction

function! MessageRecall#OnUnload( range, pendingMessageFilespec )
    " The BufLeave event isn't invoked when :quitting Vim from the current
    " buffer. We catch this from the BufUnload event. Since it is not allowed to
    " switch buffer in there, we cannot in general use this for persisting. But
    " in this special case, we only need to persist when inside the
    " to-be-unloaded buffer.
    if expand('<abuf>') == bufnr('')
	call MessageRecall#RecordMessage(a:range, a:pendingMessageFilespec)
    endif
endfunction

function! MessageRecall#PersistMessage( pendingMessageFilespec, messageStoreDirspec )
    if exists('*mkdir') && ! isdirectory(a:messageStoreDirspec)
	" Create the message store directory in case it doesn't exist yet.
	call mkdir(a:messageStoreDirspec, 'p', 0700)
    endif

    let l:messageFilespec = a:messageStoreDirspec . strftime('/message-%Y%m%d_%H%M%S')
"****D echomsg '**** rename' string(a:pendingMessageFilespec) string(l:messageFilespec)
    if rename(a:pendingMessageFilespec, l:messageFilespec) == 0
	unlet! s:pendingMessageFilespecs[a:pendingMessageFilespec]
    else
	let v:errmsg = 'MessageRecall: Failed to persist message'
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif
endfunction

function! MessageRecall#OnLeave( messageStoreDirspec )
    for l:filespec in keys(s:pendingMessageFilespecs)
	call MessageRecall#PersistMessage(l:filespec, a:messageStoreDirspec)
    endfor
endfunction

let s:pendingMessageFilespecs = {}
function! MessageRecall#Setup( messageStoreDirspec, range )
    let l:pendingMessageFilespec = tempname()
    let s:pendingMessageFilespecs[l:pendingMessageFilespec] = 1

    augroup MessageRecall
	autocmd! * <buffer>
	execute printf('autocmd BufLeave <buffer> call MessageRecall#RecordMessage(%s, %s)', string(a:range), string(l:pendingMessageFilespec))
	execute printf('autocmd BufUnload <buffer> call MessageRecall#OnUnload(%s, %s)', string(a:range), string(l:pendingMessageFilespec))
	execute printf('autocmd BufDelete <buffer> call MessageRecall#PersistMessage(%s, %s)', string(l:pendingMessageFilespec), string(a:messageStoreDirspec))
	execute printf('autocmd VimLeavePre * call MessageRecall#OnLeave(%s)', string(a:messageStoreDirspec))
    augroup END
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
