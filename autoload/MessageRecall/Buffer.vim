" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	12-Jun-2012	file creation

function! s:GetRange( range )
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    let l:save_reg = getreg('"')
    let l:save_regmode = getregtype('"')
	silent execute a:range . 'yank'
	let l:contents = @"
    call setreg('"', l:save_reg, l:save_regmode)
    let &clipboard = l:save_clipboard

    return l:contents
endfunction

function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range )
    if empty(a:filespec)
	let l:files = split(glob(a:messageStoreDirspec . '/message-*'), "\n")
	let l:filespec = get(l:files, -1 * a:count, '')
	if empty(l:filespec)
	    let v:errmsg = printf('Only %d messages available', len(l:files))
	    echohl ErrorMsg
	    echomsg v:errmsg
	    echohl None

	    return
	endif
    else
	let l:filespec = a:filespec
    endif

    let l:insertPoint = ''
    if a:isReplace || s:GetRange(a:range) =~# '^\_s*$'
	silent execute a:range 'delete _'
	let b:MessageRecall_Filespec = l:filespec
	let l:insertPoint = 0
    endif

    execute 'keepalt' l:insertPoint . 'read' escapings#fnameescape(l:filespec)

    if l:insertPoint == 0
	let b:MessageRecall_ChangedTick = b:changedtick
    endif
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, messageStoreDirspec, range )
    if ! &l:modified || exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	silent execute a:range 'delete _'
	execute 'keepalt' (line('.') - 1) . 'put =strftime(''%H:%M:%S'')'
	let b:MessageRecall_Filespec = "l:messageFilespec"
	let b:MessageRecall_ChangedTick = b:changedtick
    else
	"call MessageRecall#Buffer#Preview(a:messageStoreDirspec)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
