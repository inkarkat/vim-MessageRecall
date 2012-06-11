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
let s:save_cpo = &cpo
set cpo&vim

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

let s:pathSeparator = (exists('+shellslash') && ! &shellslash ? '\' : '/')
function! MessageRecall#Buffer#Complete( messageStoreDirspec, ArgLead )
    " Complete first files from a:messageStoreDirspec for the {filename} argument,
    " then any path- and filespec from the CWD for {filespec}.
    let l:messageStoreDirspecPrefix = glob(a:messageStoreDirspec . s:pathSeparator)
    return
    \   map(
    \       reverse(
    \           map(
    \               split(
    \                   glob(a:messageStoreDirspec . s:pathSeparator . a:ArgLead . '*'),
    \                   "\n"
    \               ),
    \               'strpart(v:val, len(l:messageStoreDirspecPrefix))'
    \           )
    \       ) +
    \       map(
    \           split(
    \               glob(a:ArgLead . '*'),
    \               "\n"
    \           ),
    \           'isdirectory(v:val) ? v:val . s:pathSeparator : v:val'
    \       ),
    \       'escapings#fnameescape(v:val)'
    \   )
endfunction

function! s:GetIndexedMessageFile( messageStoreDirspec, index )
    let l:files = split(glob(a:messageStoreDirspec . s:pathSeparator . MessageRecall#Glob()), "\n")
    let l:filespec = get(l:files, a:index, '')
    if empty(l:filespec)
	let v:errmsg = printf('Only %d messages available', len(l:files))
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif

    return l:filespec
endfunction
function! s:GetMessageFilespec( count, filespec, messageStoreDirspec )
    if empty(a:filespec)
	let l:filespec = s:GetIndexedMessageFile(a:messageStoreDirspec, -1 * a:count)
    else
	if filereadable(a:filespec)
	    let l:filespec = a:filespec
	else
	    let l:filespec = a:messageStoreDirspec . s:pathSeparator . a:filespec
	    if ! filereadable(l:filespec)
		let l:filespec = ''

		let v:errmsg = 'The stored message does not exist: ' . a:filespec
		echohl ErrorMsg
		echomsg v:errmsg
		echohl None
	    endif
	endif
    endif

    return l:filespec
endfunction
function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range )
    let l:filespec = s:GetMessageFilespec(a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    let l:insertPoint = ''
    if a:isReplace || s:GetRange(a:range) =~# '^\_s*$'
	silent execute a:range 'delete _'
	let b:MessageRecall_Filename = fnamemodify(l:filespec, ':t')
	let l:insertPoint = '0'
    endif

    execute 'keepalt' l:insertPoint . 'read' escapings#fnameescape(l:filespec)

    if l:insertPoint ==# '0'
	let b:MessageRecall_ChangedTick = b:changedtick
    endif
endfunction
function! MessageRecall#Buffer#Preview( count, filespec, messageStoreDirspec, range )
    let l:filespec = s:GetMessageFilespec(a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    let l:keepFiletypeCommand = (empty(&l:filetype) ? '+setlocal\ readonly' : printf('+setlocal\ readonly\|setf\ %s', escape(&l:filetype, '\')))
    execute 'keepalt pedit' l:keepFiletypeCommand escapings#fnameescape(l:filespec)
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec, range )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	call EditSimilar#Next#Open(
	\   'MessageRecall!',
	\   0,
	\   a:messageStoreDirspec . s:pathSeparator . b:MessageRecall_Filename,
	\   a:count,
	\   (a:isPrevious ? -1 : 1),
	\   MessageRecall#Glob()
	\)
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

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
