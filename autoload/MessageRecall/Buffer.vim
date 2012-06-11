" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"   - EditSimilar/Next.vim autoload script
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

let s:glob = 'message-*'
function! s:GetIndexedMessageFile( messageStoreDirspec, index )
    let l:files = split(glob(a:messageStoreDirspec . '/' . s:glob), "\n")
    let l:filespec = get(l:files, a:index, '')
    if empty(l:filespec)
	let v:errmsg = printf('Only %d messages available', len(l:files))
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif

    return l:filespec
endfunction
function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range )
    if empty(a:filespec)
	let l:filespec = s:GetIndexedMessageFile(a:messageStoreDirspec, -1 * a:count)
	if empty(l:filespec)
	    return
	endif
    else
	let l:filespec = a:filespec
    endif

    let l:insertPoint = ''
    if a:isReplace || s:GetRange(a:range) =~# '^\_s*$'
	silent execute a:range 'delete _'
	let b:MessageRecall_Filespec = fnamemodify(l:filespec, ':p')
	let l:insertPoint = '0'
    endif

    execute 'keepalt' l:insertPoint . 'read' escapings#fnameescape(l:filespec)

    if l:insertPoint ==# '0'
	let b:MessageRecall_ChangedTick = b:changedtick
    endif
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec, range )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	call EditSimilar#Next#Open('MessageRecall!', 0, b:MessageRecall_Filespec, a:count, (a:isPrevious ? -1 : 1), s:glob)
    elseif ! &l:modified
	let l:filespec = s:GetIndexedMessageFile(a:messageStoreDirspec, a:isPrevious ? (-1 * a:count) : (a:count - 1))
	if empty(l:filespec)
	    return
	endif

	execute 'MessageRecall!' escapings#fnameescape(l:filespec)
    else
	"call MessageRecall#Buffer#Preview(a:messageStoreDirspec)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
