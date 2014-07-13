" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/plugin.vim autoload script
"   - ingo/range.vim autoload script
"   - ingo/window/preview.vim autoload script
"   - EditSimilar/Next.vim autoload script
"   - MessageRecall.vim autoload script
"   - MessageRecall/MappingsAndCommands.vim autoload script
"
" Copyright: (C) 2012-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.012	14-Jul-2014	ENH: For :MessageRecall command completion,
"				return the messages from other message stores
"				also in reverse order, so that the latest one
"				comes first.
"				Extract s:GlobMessageStores() and allow to
"				override / extend the message store(s) via
"				b:MessageRecall_MessageStores.
"   1.03.011	01-Apr-2014	Adapt to changed EditSimilar.vim interface that
"				returns the success status now.
"				Abort on error for own plugin commands.
"   1.02.010	09-Aug-2013	FIX: Must use String comparison.
"   1.02.009	08-Aug-2013	Move escapings.vim into ingo-library.
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
"				CHG: On <C-p> / <C-n> in the original message
"				buffer: When the buffer is modified and a stored
"				message is already being previewed, change the
"				semantics of count to be interpreted relative to
"				the currently previewed stored message.
"				Beforehand, one had to use increasing <C-p>,
"				2<C-p>, 3<C-p>, etc. to iterate through stored
"				messages (or go to the preview window and invoke
"				the mapping there).
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

function! s:GlobMessageStores( messageStoreDirspec, expr )
    let l:messageStores = map(
    \   ingo#plugin#setting#GetBufferLocal('MessageRecall_MessageStores', ['']),
    \   'empty(v:val) ? a:messageStoreDirspec : v:val'
    \)
    let l:filespecs = split(globpath(
    \   join(
    \       map(
    \           l:messageStores,
    \           'escape(v:val, ",")'
    \       ),
    \       ','
    \   ),
    \   a:expr
    \), '\n')

    return sort(l:filespecs, 's:SortByMessageFilename')
endfunction
function! s:SortByMessageFilename( f1, f2 )
    if a:f1 ==# a:f2
	return 0
    endif

    let l:n1 = fnamemodify(a:f1, ':t')
    let l:n2 = fnamemodify(a:f2, ':t')

    if l:n1 ==# l:n2
	return (a:f1 ># a:f2 ? 1 : -1)
    endif

    return (l:n1 ># l:n2 ? 1 : -1)
endfunction
function! MessageRecall#Buffer#Complete( messageStoreDirspec, ArgLead )
    " Complete first files from a:messageStoreDirspec for the {filename} argument,
    " then any path- and filespec from the CWD for {filespec}.
    let l:messageStoreDirspecPrefix = get(s:GlobMessageStores(a:messageStoreDirspec, ''), 0, '')

    let l:isInMessageStoreDir = (ingo#fs#path#Combine(getcwd(), '') ==# l:messageStoreDirspecPrefix)
    let l:otherPathOrFilespecs =
    \   filter(
    \       split(
    \           glob(a:ArgLead . '*'),
    \           "\n"
    \       ),
    \       'l:isInMessageStoreDir ?' .
    \           'ingo#fs#path#Combine(fnamemodify(v:val, ":p:h"), "") !=# l:messageStoreDirspecPrefix :' .
    \           '1'
    \   )
    if len(l:otherPathOrFilespecs) > 0 && l:otherPathOrFilespecs[0] =~# ingo#regexp#FromWildcard(MessageRecall#Glob(), '')
	" Return the messages from other message stores also in reverse order,
	" so that the latest one comes first.
	call reverse(l:otherPathOrFilespecs)
    endif

    return
    \   map(
    \       reverse(
    \           map(
    \		    s:GlobMessageStores(a:messageStoreDirspec, a:ArgLead . '*'),
    \               'strpart(v:val, len(l:messageStoreDirspecPrefix))'
    \           )
    \       ) +
    \       map(
    \           l:otherPathOrFilespecs,
    \           'isdirectory(v:val) ? ingo#fs#path#Combine(v:val, "") : v:val'
    \       ),
    \       'ingo#compat#fnameescape(v:val)'
    \   )
endfunction

function! s:GetIndexedMessageFilespec( messageStoreDirspec, index )
    let l:files = s:GlobMessageStores(a:messageStoreDirspec, MessageRecall#Glob())
    let l:filespec = get(l:files, a:index, '')
    if empty(l:filespec)
	if len(l:files) == 0
	    call ingo#err#Set('No messages available')
	else
	    call ingo#err#Set(printf('Only %d message%s available', len(l:files), (len(l:files) == 1 ? '' : 's')))
	endif
    endif

    return l:filespec
endfunction
function! s:GetMessageFilespec( index, filespec, messageStoreDirspec )
    if empty(a:filespec)
	let l:filespec = s:GetIndexedMessageFilespec(a:messageStoreDirspec, a:index)
    else
	if filereadable(a:filespec)
	    let l:filespec = a:filespec
	else
	    let l:filespec = ingo#fs#path#Combine(a:messageStoreDirspec, a:filespec)
	    if ! filereadable(l:filespec)
		let l:filespec = ''

		call ingo#err#Set('The stored message does not exist: ' . a:filespec)
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
    catch /^Vim\%((\a\+)\)\=:/
	if a:whenRangeNoMatch ==# 'all'
	    let l:isReplace = (ingo#range#Get('%') =~# '^\n*$')
	endif
    endtry
    return l:isReplace
endfunction
function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range, whenRangeNoMatch )
    let l:filespec = s:GetMessageFilespec(-1 * a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return 0    " Message has been set by s:GetMessageFilespec().
    endif

    let l:range = s:GetRange(a:range)
    let l:insertPoint = '.'
    if a:isReplace || s:IsReplace(l:range, a:whenRangeNoMatch)
	try
	    silent execute l:range . 'delete _'
	    let b:MessageRecall_Filespec = fnamemodify(l:filespec, ':p')
	    " After the deletion, the cursor is on the following line. Prepend
	    " before that.
	    let l:insertPoint = line('.') - 1
	catch /^Vim\%((\a\+)\)\=:/
	    if a:whenRangeNoMatch ==# 'error'
		call ingo#err#Set('MessageRecall: Failed to capture message: ' . ingo#msg#MsgFromVimException())
		return 0
	    elseif a:whenRangeNoMatch ==# 'ignore'
		" Append instead of replacing.
	    elseif a:whenRangeNoMatch ==# 'all'
		" Replace the entire buffer instead.
		silent %delete _
		let b:MessageRecall_Filespec = fnamemodify(l:filespec, ':p')
		let l:insertPoint = '0'
	    else
		throw 'ASSERT: Invalid value for a:whenRangeNoMatch: ' . string(a:whenRangeNoMatch)
	    endif
	endtry
    endif

    execute 'keepalt' l:insertPoint . 'read' ingo#compat#fnameescape(l:filespec)

    if ('' . l:insertPoint) !=# '.'
	let b:MessageRecall_ChangedTick = b:changedtick
    endif

    return 1
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
	call ingo#err#Set('No target message buffer opened')
	return 0
    endif

    let l:message = expand('%:t')
    execute l:winNr 'wincmd w'
    try
	execute 'MessageRecall' . a:bang ingo#compat#fnameescape(l:message)
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
    return 1
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
	return 0    " Message has been set by s:GetMessageFilespec().
    endif

    execute 'keepalt pedit +' . escape(MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, &l:filetype), ' \') ingo#compat#fnameescape(fnamemodify(l:filespec, ':p'))
    return 1
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec, range, whenRangeNoMatch, targetBufNr )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	" Replace again in the original message buffer.
	return s:OpenNext(
	\   a:messageStoreDirspec,
	\   'MessageRecall!',
	\   b:MessageRecall_Filespec,
	\   a:count,
	\   (a:isPrevious ? -1 : 1),
	\)
    elseif ! &l:modified && s:IsReplace(s:GetRange(a:range), a:whenRangeNoMatch)
	" Replace for the first time in the original message buffer.
	let l:filespec = s:GetIndexedMessageFilespec(a:messageStoreDirspec, a:isPrevious ? (-1 * a:count) : (a:count - 1))
	if empty(l:filespec)
	    return 0    " Message has been set by s:GetIndexedMessageFilespec().
	endif

	try
	    execute 'MessageRecall!' ingo#compat#fnameescape(l:filespec)
	catch /^Vim\%((\a\+)\)\=:/
	    call ingo#err#SetVimException()
	    return 0
	endtry
	return 1
    else
	" Show in preview window.
	let l:previewWinNr = ingo#window#preview#IsPreviewWindowVisible()
	let l:previewBufNr = winbufnr(l:previewWinNr)
	if ! l:previewWinNr || ! getbufvar(l:previewBufNr, 'MessageRecall_Buffer')
	    " No stored message previewed yet: Open the a:count'th previous /
	    " first stored message in the preview window.
	    return MessageRecall#Buffer#Preview(a:isPrevious, a:count, '', a:messageStoreDirspec, a:targetBufNr)
	else
	    " DWIM: The semantics of a:count are interpreted relative to the currently previewed stored message.
	    return s:OpenNext(
	    \   a:messageStoreDirspec,
	    \   'pedit +' . escape(MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, &l:filetype), ' \'),
	    \   fnamemodify(bufname(l:previewBufNr), ':p'),
	    \   a:count,
	    \   (a:isPrevious ? -1 : 1),
	    \)
	endif
    endif
endfunction
function! s:OpenNext( messageStoreDirspec, opencmd, filespec, difference, direction )
    let l:files =
    \   map(
    \       filter(
    \           s:GlobMessageStores(a:messageStoreDirspec, MessageRecall#Glob()),
    \           '! isdirectory(v:val)'
    \       ),
    \       'ingo#fs#path#Normalize(fnamemodify(v:val, ":p"))'
    \   )

    let l:currentIndex = index(l:files, ingo#fs#path#Normalize(a:filespec))
    if l:currentIndex == -1
	if len(l:files) == 0
	    call ingo#err#Set('No messages in this directory')
	else
	    call ingo#err#Set('Cannot locate current file: ' . a:filespec)
	endif
	return 0
    elseif l:currentIndex == 0 && len(l:files) == 1
	call ingo#err#Set('This is the sole message in the directory')
	return 0
    elseif l:currentIndex == 0 && a:direction == -1
	call ingo#err#Set('No previous message')
	return 0
    elseif l:currentIndex == (len(l:files) - 1) && a:direction == 1
	call ingo#err#Set('No next message')
	return 0
    endif

    " A passed difference of 0 means that no [count] was specified and thus
    " skipping over missing numbers is enabled.
    let l:difference = max([a:difference, 1])

    let l:offset = a:direction * l:difference
    let l:replacementIndex = l:currentIndex + l:offset
    let l:replacementIndex =
    \   max([
    \       min([l:replacementIndex, len(l:files) - 1]),
    \       0
    \   ])
    let l:replacementFilespec = l:files[l:replacementIndex]

    " Note: The a:isCreateNew flag has no meaning here, as all replacement
    " files do already exist.
    return EditSimilar#Open(a:opencmd, 0, 0, a:filespec, l:replacementFilespec, '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
