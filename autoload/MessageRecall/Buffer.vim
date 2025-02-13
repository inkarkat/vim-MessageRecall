" MessageRecall/Buffer.vim: Functionality for message buffers.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2024 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! MessageRecall#Buffer#ExtendMessageStore( messageStoreDirspec, messageStore )
    return (empty(v:val) ? a:messageStoreDirspec : ingo#fs#path#Normalize(fnamemodify(v:val, ':p')))
endfunction
function! s:GlobMessageStores( messageStoreDirspec, expr, ... )
    let l:messageStores = (a:0 && ! empty(a:1) ? a:1 : map(
    \   ingo#plugin#setting#GetBufferLocal('MessageRecall_MessageStores', ['']),
    \   'MessageRecall#Buffer#ExtendMessageStore(a:messageStoreDirspec, v:val)'
    \))
    " Note: Need to ensure absolute filespecs for the
    " b:MessageRecall_MessageStores, because when previewing the contents of
    " different stores, the CWD may change. Therefore, apply the changes (also
    " the expansion of the empty value, as this doesn't hurt) directly on the
    " underlying configuration variable.

    let l:filespecs = ingo#compat#globpath(
    \   join(
    \       map(
    \           l:messageStores,
    \           'escape(v:val, ",")'
    \       ),
    \       ','
    \   ),
    \   a:expr
    \, 0, 1)

    return sort(l:filespecs, 's:SortByMessageFilename')
endfunction
function! s:SortByMessageFilename( f1, f2 )
    " Oldest timestamp first.
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
    \       ingo#compat#glob(a:ArgLead . '*', 0, 1),
    \       'l:isInMessageStoreDir ?' .
    \           'ingo#fs#path#Combine(fnamemodify(v:val, ":p:h"), "") !=# l:messageStoreDirspecPrefix :' .
    \           '1'
    \   )
    if len(l:otherPathOrFilespecs) > 0 && l:otherPathOrFilespecs[0] =~# ingo#regexp#fromwildcard#AnchoredToPathBoundaries(MessageRecall#Glob(), '')
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

function! s:GetFiles( messageStoreDirspec, targetBufNr, ... )
    let l:messageStores = (a:targetBufNr == -1 ? [] : getbufvar(a:targetBufNr, 'MessageRecall_MessageStores'))
    let l:files =
    \   map(
    \       filter(
    \           s:GlobMessageStores(a:messageStoreDirspec, MessageRecall#Glob(), l:messageStores),
    \           '! isdirectory(v:val)'
    \       ),
    \       'ingo#fs#path#Normalize(fnamemodify(v:val, ":p"))'
    \   )

    if (a:0 && a:1 < 0)
	let l:files = l:files[(a:1):-1]
    elseif (a:0 && a:1 > 0)
	let l:files = l:files[0 :(a:1 - 1)]
    endif
    return l:files
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
function! s:IsEmpty( rangeContents, ignorePattern ) abort
    return (a:rangeContents =~# '^\n*$' ||
    \   (! empty(a:ignorePattern) && a:rangeContents =~# a:ignorePattern)
    \)
endfunction
function! s:IsReplace( range, whenRangeNoMatch, ignorePattern )
    let l:hasValidRange = 0
    for l:range in ingo#list#Make(a:range)
	try
	    let l:rangeContents = ingo#range#Get(l:range)
	    let l:hasValidRange = 1
	    break
	catch /^Vim\%((\a\+)\)\=:/
	    " Try other range(s).
	endtry
    endfor
    if ! l:hasValidRange
	let l:rangeContents = (a:whenRangeNoMatch ==# 'all'
	\   ? ingo#range#Get('%')
	\   : ''
	\)
    endif
    return [s:IsEmpty(l:rangeContents, a:ignorePattern), l:range, l:rangeContents]
endfunction
function! MessageRecall#Buffer#Recall( isReplace, count, filespec, messageStoreDirspec, range, whenRangeNoMatch, ignorePattern, replacedMessageRegister )
    let l:filespec = s:GetMessageFilespec(-1 * a:count, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return 0    " Message has been set by s:GetMessageFilespec().
    endif
    return s:ReplaceWithFilespec(a:isReplace, l:filespec, a:range, a:whenRangeNoMatch, a:ignorePattern, a:replacedMessageRegister)
endfunction
function! s:ReplaceWithFilespec( isReplace, filespec, range, whenRangeNoMatch, ignorePattern, replacedMessageRegister )
    let l:insertPoint = '.'
    let [l:isReplace, l:range, l:rangeContents] = s:IsReplace(a:range, a:whenRangeNoMatch, a:ignorePattern)
    if l:isReplace || a:isReplace
	try
	    if l:rangeContents ==# "\n"
		" Keep a single empty line by just positioning the cursor to, without deleting
		" the range. This is important to properly insert a recalled message before Git
		" commit trailers (which must always be separated from the message body via an
		" empty line).
		silent execute ingo#compat#commands#keeppatterns() l:range
	    else
		silent execute ingo#compat#commands#keeppatterns() l:range . 'delete' (empty(a:replacedMessageRegister) ? '_' : a:replacedMessageRegister)
	    endif
	    let b:MessageRecall_Filespec = fnamemodify(a:filespec, ':p')
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
		silent execute '%delete' (empty(a:replacedMessageRegister) ? '_' : a:replacedMessageRegister)
		let b:MessageRecall_Filespec = fnamemodify(a:filespec, ':p')
		let l:insertPoint = '0'
	    else
		throw 'ASSERT: Invalid value for a:whenRangeNoMatch: ' . string(a:whenRangeNoMatch)
	    endif
	endtry
    endif

    execute 'keepalt' l:insertPoint . 'read' ingo#compat#fnameescape(a:filespec)

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
function! MessageRecall#Buffer#GetPreviewCommands( targetBufNr, filetype, subDirForUserProvidedDirspec )
    " Pass the target buffer number to enable the mappings and commands in the
    " previewed buffer to access a buffer local message stores configuration.
    return
    \	printf('call MessageRecall#MappingsAndCommands#PreviewSetup(%d,%s,%s)', a:targetBufNr, string(a:filetype), string(a:subDirForUserProvidedDirspec)) .
    \	'|setlocal readonly' .
    \   (empty(a:filetype) ? '' : printf('|setf %s', a:filetype))
endfunction
function! MessageRecall#Buffer#Preview( isPrevious, count, filespec, messageStoreDirspec, targetBufNr, subDirForUserProvidedDirspec )
    let l:index = (a:isPrevious ? -1 * a:count : a:count - 1)
    let l:filespec = s:GetMessageFilespec(l:index, a:filespec, a:messageStoreDirspec)
    if empty(l:filespec)
	return 0    " Message has been set by s:GetMessageFilespec().
    endif

    return s:Open('', MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, &l:filetype, a:subDirForUserProvidedDirspec), l:filespec)
endfunction

function! MessageRecall#Buffer#Replace( isPrevious, count, messageStoreDirspec, range, whenRangeNoMatch, ignorePattern, replacedMessageRegister, targetBufNr, subDirForUserProvidedDirspec )
    if exists('b:MessageRecall_ChangedTick') && b:MessageRecall_ChangedTick == b:changedtick
	" Replace again in the original message buffer.
	let l:replacementFilespec = MessageRecall#Buffer#OpenNext(
	\   a:messageStoreDirspec,
	\   'return', '',
	\   b:MessageRecall_Filespec,
	\   a:count,
	\   (a:isPrevious ? -1 : 1),
	\   -1
	\)
	return (l:replacementFilespec is# 0 ?
	\   0 :
	\   s:ReplaceWithFilespec(1, l:replacementFilespec, a:range, a:whenRangeNoMatch, a:ignorePattern, '')
	\)
	" Do not use a:replacedMessageRegister here, as we're replacing a previous recalled message, not original buffer contents.
    elseif ! &l:modified && s:IsReplace(s:GetRange(a:range), a:whenRangeNoMatch, a:ignorePattern)[0]
	" Replace for the first time in the original message buffer.
	return MessageRecall#Buffer#Recall(1, a:isPrevious ? a:count : (-1 * (a:count - 1)), '', a:messageStoreDirspec, a:range, a:whenRangeNoMatch, a:ignorePattern, a:replacedMessageRegister)
    else
	" Show in preview window.
	let l:previewWinNr = ingo#window#preview#IsPreviewWindowVisible()
	let l:previewBufNr = winbufnr(l:previewWinNr)
	if ! l:previewWinNr || ! getbufvar(l:previewBufNr, 'MessageRecall_Buffer')
	    " No stored message previewed yet: Open the a:count'th previous /
	    " first stored message in the preview window.
	    return MessageRecall#Buffer#Preview(a:isPrevious, a:count, '', a:messageStoreDirspec, a:targetBufNr, a:subDirForUserProvidedDirspec)
	else
	    " DWIM: The semantics of a:count are interpreted relative to the currently previewed stored message.
	    return MessageRecall#Buffer#OpenNext(
	    \   a:messageStoreDirspec,
	    \   '', MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, &l:filetype, a:subDirForUserProvidedDirspec),
	    \   fnamemodify(bufname(l:previewBufNr), ':p'),
	    \   a:count,
	    \   (a:isPrevious ? -1 : 1),
	    \   -1
	    \)
	endif
    endif
endfunction
function! MessageRecall#Buffer#OpenNext( messageStoreDirspec, opencmd, exFileCommands, filespec, difference, direction, targetBufNr )
    let l:files = s:GetFiles(a:messageStoreDirspec, a:targetBufNr)

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
    return (a:opencmd ==# 'return' ?
    \   l:replacementFilespec :
    \   s:Open(a:opencmd, a:exFileCommands, l:replacementFilespec)
    \)
endfunction
function! s:Open( opencmd, exFileCommands, filespec )
    let l:exFileOptionsAndCommands = (empty(a:exFileCommands) ? '' : '+' . escape(a:exFileCommands, ' \'))
    try
	if empty(a:opencmd)
	    call ingo#window#preview#OpenFilespec(fnamemodify(a:filespec, ':p'), {
	    \   'isSilent': 0, 'isBang': 1,
	    \   'exFileOptionsAndCommands': l:exFileOptionsAndCommands
	    \})
	else
	    execute a:opencmd l:exFileOptionsAndCommands ingo#compat#fnameescape(a:filespec)
	endif
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

function! MessageRecall#Buffer#Grep( targetBufNr, messageStoreDirspec, count, arguments )
    let l:success = s:Grep(a:targetBufNr, a:messageStoreDirspec, a:count, 'lgrep!', a:arguments, 'ingo#compat#shellescape')
    redraw! " The external command has messed up the screen.
    return l:success
endfunction
function! MessageRecall#Buffer#VimGrep( targetBufNr, messageStoreDirspec, count, arguments )
    " We want to pass the "j" flag to :vimgrep, so that it does not jump to the
    " first match. As flags can only be passed to the /{pattern}/ form, we need
    " to turn the {pattern} form into the former.
    let l:arguments = (ingo#cmdargs#pattern#IsDelimited(a:arguments, 'g\?') ?
    \   a:arguments :
    \   '/' . escape(a:arguments, '/') . '/'
    \) . 'j'
    let l:success = s:Grep(a:targetBufNr, a:messageStoreDirspec, a:count, 'lvimgrep!', l:arguments, 'ingo#compat#fnameescape')
    call histdel('search', -1)
    return l:success
endfunction
function! s:Grep( targetBufNr, messageStoreDirspec, count, grepCommand, arguments, EscapeFunction )
    let l:files = s:GetFiles(a:messageStoreDirspec, a:targetBufNr, -1 * a:count)
    try
	silent execute a:grepCommand a:arguments join(map(reverse(l:files), empty(a:EscapeFunction) ? 'v:val' : 'call(a:EscapeFunction, [v:val])'), ' ')
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

function! MessageRecall#Buffer#List( targetBufNr, messageStoreDirspec, count )
    " External grep is faster, because it does not need to load each file into a
    " Vim buffer. However, we need a POSIX grep that supports the -m /
    " --max-count option. If that isn't the case, fall back to slower built-in
    "  :vimgrep.
    if &grepprg =~# '^grep '
	let l:success = MessageRecall#Buffer#Grep(a:targetBufNr, a:messageStoreDirspec, a:count, '-m1 .')
    else
	let l:success = MessageRecall#Buffer#VimGrep(a:targetBufNr, a:messageStoreDirspec, a:count, '/\%^\n*\zs./')
    endif

    if ! l:success
	return 0
    endif

    try
	lopen
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

function! MessageRecall#Buffer#Prune( targetBufNr, messageStoreDirspec, isForce, count, arguments )
    if empty(a:arguments)
	let l:files = s:GetFiles(a:messageStoreDirspec, a:targetBufNr, a:count)
    else
	let l:messageStores = (a:targetBufNr == -1 ? [] : getbufvar(a:targetBufNr, 'MessageRecall_MessageStores'))
	let l:files =
	\   map(
	\       filter(
	\           s:GlobMessageStores(a:messageStoreDirspec, a:arguments, l:messageStores),
	\           '! isdirectory(v:val)'
	\       ),
	\       'ingo#fs#path#Normalize(fnamemodify(v:val, ":p"))'
	\   )
    endif

    if empty(l:files)
	call ingo#err#Set('No messages' . (empty(a:arguments) ? '' : ' matching ' . a:arguments))
	return 0
    endif

    if ! a:isForce
	let l:confirmationMessage = (len(l:files) == 1 ?
	\   printf('Really delete %s?', l:files[0]) :
	\   printf('Really delete %d messages (from %s to %s)?', len(l:files), fnamemodify(l:files[0], ':t:r'), fnamemodify(l:files[-1], ':t:r'))
	\)
	if confirm(l:confirmationMessage, "&Yes\n&No", 0, 'Question') != 1
	    return 1
	endif
    endif

    let l:deleteCnt = 0
    for l:file in l:files
	if delete(l:file) == 0
	    let l:deleteCnt += 1
	endif
    endfor
    call ingo#msg#StatusMsg(printf('%d message%s deleted', l:deleteCnt, (l:deleteCnt == 1 ? '' : 's')))
    return 1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
