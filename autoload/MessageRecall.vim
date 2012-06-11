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

function! s:PendingMessageFilespec( messageStoreDirspec )
    return a:messageStoreDirspec . '/.pending'
endfunction
function! MessageRecall#RecordMessage( messageStoreDirspec, range )
    try
	if exists('*mkdir') && ! isdirectory(a:messageStoreDirspec)
	    " Create the message store directory in case it doesn't exist yet.
	    call mkdir(a:messageStoreDirspec, 'p')
	    " Note: We do not need to check for success, the subsequent :write
	    " will complain for us with a good error message.
	endif

	execute 'silent keepalt' a:range . 'write!' escapings#fnameescape(s:PendingMessageFilespec(a:messageStoreDirspec))
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endtry
endfunction

function! MessageRecall#OnUnload( messageStoreDirspec, range )
    " The BufLeave event isn't invoked when :quitting Vim from the current
    " buffer. We catch this from the BufUnload event. Since it is not allowed to
    " switch buffer in there, we cannot in general use this for persisting. But
    " in this special case, we only need to persist when inside the
    " to-be-unloaded buffer.
    if expand('<abuf>') == bufnr('')
	call MessageRecall#RecordMessage(a:messageStoreDirspec, a:range)
    endif
endfunction

function! MessageRecall#PersistMessage( messageStoreDirspec )
    let l:messageFilespec = a:messageStoreDirspec . strftime('/message-%Y%m%d_%H%M%S')
    if rename(s:PendingMessageFilespec(a:messageStoreDirspec), l:messageFilespec) != 0
	let v:errmsg = 'MessageRecall: Failed to persist message'
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif
endfunction

function! MessageRecall#Setup( messageStoreDirspec, range )
    augroup MessageRecall
	autocmd! * <buffer>
	execute printf('autocmd BufLeave <buffer> call MessageRecall#RecordMessage(%s, %s)', string(a:messageStoreDirspec), string(a:range))
	execute printf('autocmd BufUnload <buffer> call MessageRecall#OnUnload(%s, %s)', string(a:messageStoreDirspec), string(a:range))
	execute printf('autocmd BufDelete <buffer> call MessageRecall#PersistMessage(%s)', string(a:messageStoreDirspec))
    augroup END
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
