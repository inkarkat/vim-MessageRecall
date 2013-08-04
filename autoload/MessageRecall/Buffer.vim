" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/range.vim autoload script
"   - EditSimilar/Next.vim autoload script
"   - MessageRecall.vim autoload script
"   - MessageRecall/MappingsAndCommands.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.02.008	05-Aug-2013	Factor out s:GetRange() and s:IsReplace() from
"				MessageRecall#Buffer#Recall().
"				CHG: Only replace on <C-p> / <C-n> in the
"				message buffer when the considered range is just
"				empty lines. I came to dislike the previous
"				replacement also when the message had been
"				persisted.
"				Minor: Correctly handle replacement of ranges
"				that do not start at the beginning of the
"				buffer. Must insert before the current line
"				then, not always line 0.
"   1.02.007	23-Jul-2013	Move ingointegration#GetRange() to
"				ingo#range#Get().
"   1.02.006	14-Jun-2013	Use ingo/msg.vim.
"   1.02.005	01-Jun-2013	Move ingofile.vim into ingo-library.
"   1.01.004	12-Jul-2012	BUG: ingointegration#GetRange() can throw E486,
"				causing a script error when replacing a
"				non-matching commit message buffer; :silent! the
"				invocation. Likewise, the replacement of the
"				message can fail, too. We need the
"				a:options.whenRangeNoMatch value to properly
"				react to that.
"				Improve message about limited number of stored
"				messages for 0 and 1 occurrences.
"   1.00.003	19-Jun-2012	Fix syntax error in
"				MessageRecall#Buffer#Complete().
"				Extract mapping and command setup to
"				MessagRecall/MappingsAndCommands.vim.
"				Do not return duplicate completion matches when
"				completing from the message store directory.
"				This happens all the time with 'autochdir' and
"				doing :MessageView from the preview window.
"				Prune unnecessary a:range argument.
"				Pass in a:targetBufNr to
"				MessageRecall#Buffer#Preview(), now that it is
"				also used from inside the preview window, and do
"				the same to MessageRecall#Buffer#Replace() for
"				consistency.
"   1.00.002	18-Jun-2012	Completed initial functionality.
"				Implement previewing via CTRL-P / CTRL-N.
"	001	12-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! MessageRecall#Buffer#Complete( messageStoreDirspec, ArgLead )
    " Complete first files from a:messageStoreDirspec for the {filename} argument,
    " then any path- and filespec from the CWD for {filespec}.
    let l:messageStoreDirspecPrefix = glob(ingo#fs#path#Combine(a:messageStoreDirspec, ''))
    let l:isInMessageStoreDir = (ingo#fs#path#Combine(getcwd(), '') ==# l:messageStoreDirspecPrefix)
    return
    \   map(
    \       reverse(
    \           map(
    \               split(
    \                   glob(ingo#fs#path#Combine(a:messageStoreDirspec, a:ArgLead . '*')),
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
    \	                'ingo#fs#path#Combine(fnamemodify(v:val, ":p:h"), "") !=# l:messageStoreDirspecPrefix :' .
    \	                '1'
    \           ),
    \           'isdirectory(v:val) ? ingo#fs#path#Combine(v:val, "") : v:val'
    \       ),
    \       'escapings#fnameescape(v:val)'
    \   )
endfunction

function! s:GetIndexedMessageFile( messageStoreDirspec, index )
    let l:files = split(glob(ingo#fs#path#Combine(a:messageStoreDirspec, MessageRecall#Glob())), "\n")
    let l:filespec = get(l:files, a:index, '')
    if empty(l:filespec)
	if len(l:files) == 0
	    call ingo#msg#ErrorMsg('No messages available')
	else
	    call ingo#msg#ErrorMsg(printf('Only %d message%s available', len(l:files), (len(l:files) == 1 ? '' : 's')))
	endif
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
	    let l:filespec = ingo#fs#path#Combine(a:messageStoreDirspec, a:filespec)
	    if ! filereadable(l:filespec)
		let l:filespec = ''

		call ingo#msg#ErrorMsg('The stored message does not exist: ' . a:filespec)
	    endif
	endif
    endif

    return l:filespec
endfunction
function! s:GetRange( range )
    return (empty(a:range) ? '%' : a:range)
endfunction
function! s:IsReplace( range, whenRangeNoMatch )
    let l:isReplace = 0
    try
	let l:isReplace = (ingo#range#Get(a:range) =~# '^\n*$')
    catch /^Vim\%((\a\+)\)\=:E/
	if a:whenRangeNoMatch ==# 'all'
	    let l:isReplace = (ingo#range#Get('%') =~# '^\n*$')
	endif
    endtry
    return l:isReplace
endfunction
function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range, whenRangeNoMatch )
    let l:filespec = s:GetMessageFilespec(-1 * a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    let l:range = s:GetRange(a:range)
    let l:insertPoint = '.'
    if a:isReplace || s:IsReplace(l:range, a:whenRangeNoMatch)
	try
	    silent execute l:range . 'delete _'
	    let b:MessageRecall_Filename = fnamemodify(l:filespec, ':t')
	    " After the deletion, the cursor is on the following line. Prepend
	    " before that.
	    let l:insertPoint = line('.') - 1
	catch /^Vim\%((\a\+)\)\=:E/
	    if a:whenRangeNoMatch ==# 'error'
		call ingo#msg#ErrorMsg('MessageRecall: Failed to capture message: ' . ingo#msg#MsgFromVimException())
		return
	    elseif a:whenRangeNoMatch ==# 'ignore'
		" Append instead of replacing.
	    elseif a:whenRangeNoMatch ==# 'all'
		" Replace the entire buffer instead.
		silent %delete _
		let b:MessageRecall_Filename = fnamemodify(l:filespec, ':t')
		let l:insertPoint = '0'
	    else
		throw 'ASSERT: Invalid value for a:whenRangeNoMatch: ' . string(a:whenRangeNoMatch)
	    endif
	endtry
    endif

    execute 'keepalt' l:insertPoint . 'read' escapings#fnameescape(l:filespec)

    if l:insertPoint !=# '.'
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
	call ingo#msg#ErrorMsg('No target message buffer opened')
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
function! MessageRecall#Buffer#Preview( isPrevious, count, filespec, messageStoreDirspec, targetBufNr )
    let l:index = (a:isPrevious ? -1 * a:count : a:count - 1)
    let l:filespec = s:GetMessageFilespec(l:index, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return
    endif

    execute 'keepalt pedit +' . escape(MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, &l:filetype), ' \') escapings#fnameescape(l:filespec)
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec, range, whenRangeNoMatch, targetBufNr )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	call EditSimilar#Next#Open(
	\   'MessageRecall!',
	\   0,
	\   ingo#fs#path#Combine(a:messageStoreDirspec, b:MessageRecall_Filename),
	\   a:count,
	\   (a:isPrevious ? -1 : 1),
	\   MessageRecall#Glob()
	\)
    elseif ! &l:modified && s:IsReplace(s:GetRange(a:range), a:whenRangeNoMatch)
	let l:filespec = s:GetIndexedMessageFile(a:messageStoreDirspec, a:isPrevious ? (-1 * a:count) : (a:count - 1))
	if empty(l:filespec)
	    return
	endif

	execute 'MessageRecall!' escapings#fnameescape(l:filespec)
    else
	call MessageRecall#Buffer#Preview(a:isPrevious, a:count, '', a:messageStoreDirspec, a:targetBufNr)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
