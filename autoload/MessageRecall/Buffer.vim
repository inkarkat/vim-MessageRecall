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

function! MessageRecall#Buffer#Recall( count, messageStoreDirspec, range )
    let l:messageFiles = split(glob(a:messageStoreDirspec . '/message-*'), "\n")
    let l:messageFilespec = get(l:messageFiles, -1 * a:count, '')
    if empty(l:messageFilespec)
	let v:errmsg = printf('Only %d messages available', len(l:messageFiles))
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    endif

    execute 'keepalt read' escapings#fnameescape(l:messageFilespec)

    if line('.') == 2 && empty(getline(1))
	" DWIM: Insert the message at the top of the buffer if the command was
	" triggered from an empty first line.
	1delete _
    endif
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, messageStoreDirspec, range )
    if &l:modified
	"call MessageRecall#Buffer#Preview(a:messageStoreDirspec)
    else
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
