" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"   - ingofile.vim autoload script
"   - ingointegration.vim autoload script
"   - EditSimilar/Next.vim autoload script
"   - MessageRecall.vim autoload script
"   - MessageRecall/MappingsAndCommands.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.003	19-Jun-2012	Fix syntax error in
"				MessageRecall#Buffer#Complete().
"				Extract mapping and command setup to
"				MessagRecall/MappingsAndCommands.vim.
"				Do not return duplicate completion matches when
"				completing from the message store directory.
"				This happens all the time with 'autochdir' and
"				doing :MessageView from the preview window.
"				Prune unnecessary a:range argument.
"   1.00.002	18-Jun-2012	Completed initial functionality.
"				Implement previewing via CTRL-P / CTRL-N.
"	001	12-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! MessageRecall#Buffer#Complete( messageStoreDirspec, ArgLead )
    " Complete first files from a:messageStoreDirspec for the {filename} argument,
    " then any path- and filespec from the CWD for {filespec}.
    let l:messageStoreDirspecPrefix = glob(ingofile#CombineToFilespec(a:messageStoreDirspec, ''))
    let l:isInMessageStoreDir = (ingofile#CombineToFilespec(getcwd(), '') ==# l:messageStoreDirspecPrefix)
    return
    \   map(
    \       reverse(
    \           map(
    \               split(
    \                   glob(ingofile#CombineToFilespec(a:messageStoreDirspec, a:ArgLead . '*')),
    \                   "\n"
    \               ),
    \               'strpart(v:val, len(l:messageStoreDirspecPrefix))'
    \           )
    \       ) +
    \       map(
    \           filter(
    \               split(
    \                   glob(a:ArgLead . '*'),
    \                   "\n"
    \               ),
    \               'l:isInMessageStoreDir ?' .
    \	                'ingofile#CombineToFilespec(fnamemodify(v:val, ":p:h"), "") !=# l:messageStoreDirspecPrefix :' .
    \	                '1'
    \           ),
    \           'isdirectory(v:val) ? ingofile#CombineToFilespec(v:val, "") : v:val'
    \       ),
    \       'escapings#fnameescape(v:val)'
    \   )
endfunction

function! s:GetIndexedMessageFile( messageStoreDirspec, index )
    let l:files = split(glob(ingofile#CombineToFilespec(a:messageStoreDirspec, MessageRecall#Glob())), "\n")
    let l:filespec = get(l:files, a:index, '')
    if empty(l:filespec)
	let v:errmsg = printf('Only %d messages available', len(l:files))
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif

    return l:filespec
endfunction
function! s:GetMessageFilespec( index, filespec, messageStoreDirspec )
    if empty(a:filespec)
	let l:filespec = s:GetIndexedMessageFile(a:messageStoreDirspec, a:index)
    else
	if filereadable(a:filespec)
	    let l:filespec = a:filespec
	else
	    let l:filespec = ingofile#CombineToFilespec(a:messageStoreDirspec, a:filespec)
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
    let l:filespec = s:GetMessageFilespec(-1 * a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    let l:range = (empty(a:range) ? '%' : a:range)
    let l:insertPoint = ''
    if a:isReplace || ingointegration#GetRange(l:range) =~# '^\n*$'
	silent execute l:range 'delete _'
	let b:MessageRecall_Filename = fnamemodify(l:filespec, ':t')
	let l:insertPoint = '0'
    endif

    execute 'keepalt' l:insertPoint . 'read' escapings#fnameescape(l:filespec)

    if l:insertPoint ==# '0'
	let b:MessageRecall_ChangedTick = b:changedtick
    endif
endfunction

function! MessageRecall#Buffer#PreviewRecall( bang, targetBufNr )
    let l:winNr = -1
    if a:targetBufNr >= 1
	" We got a target buffer passed in.
	let l:winNr = bufwinnr(a:targetBufNr)
    elseif ! empty(&l:filetype)
	" No target buffer is known, go search for a buffer with the same
	" filetype that is not a stored message.
	let l:winNr =
	\   bufwinnr(
	\       get(
	\           filter(
	\               tabpagebuflist(),
	\               'getbufvar(v:val, "&filetype") ==# &filetype && ! MessageRecall#IsStoredMessage(bufname(v:val))'
	\           ),
	\           0,
	\           -1
	\       )
	\   )
    endif

    if l:winNr == -1
	let v:errmsg = 'No target message buffer opened'
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    endif

    let l:message = expand('%:t')
    execute l:winNr 'wincmd w'
    execute 'MessageRecall' . a:bang escapings#fnameescape(l:message)
endfunction
function! MessageRecall#Buffer#GetPreviewCommands( targetBufNr, filetype )
    return
    \	printf('call MessageRecall#MappingsAndCommands#PreviewSetup(%d,%s)', a:targetBufNr, string(a:filetype)) .
    \	'|setlocal readonly' .
    \   (empty(a:filetype) ? '' : printf('|setf %s', a:filetype))
endfunction
function! MessageRecall#Buffer#Preview( isPrevious, count, filespec, messageStoreDirspec )
    let l:index = (a:isPrevious ? -1 * a:count : a:count - 1)
    let l:filespec = s:GetMessageFilespec(l:index, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    execute 'keepalt pedit +' . escape(MessageRecall#Buffer#GetPreviewCommands(bufnr(''), &l:filetype), ' \') escapings#fnameescape(l:filespec)
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	call EditSimilar#Next#Open(
	\   'MessageRecall!',
	\   0,
	\   ingofile#CombineToFilespec(a:messageStoreDirspec, b:MessageRecall_Filename),
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
	call MessageRecall#Buffer#Preview(a:isPrevious, a:count, '', a:messageStoreDirspec)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
