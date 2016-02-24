" MessageRecall/Stores.vim: Choosing the message stores.
"
" DEPENDENCIES:
"   - MessageRecall/Buffer.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/fs/path.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.001	15-Jul-2014	file creation

function! s:GetConfiguredMessageStores()
    let l:stores = {}
    if exists('g:MessageRecall_ConfiguredMessageStores')
	call extend(l:stores, g:MessageRecall_ConfiguredMessageStores)
    endif
    if exists('b:MessageRecall_ConfiguredMessageStores')
	call extend(l:stores, b:MessageRecall_ConfiguredMessageStores)
    endif
    return l:stores
endfunction
function! s:GetIdentifiers()
    return keys(s:GetConfiguredMessageStores())
endfunction
function! MessageRecall#Stores#Complete( ArgLead, CmdLine, CursorPos )
    " Initially offer only identifiers from the configuration. If there's a lead
    " (or no identifiers), complete first identifiers and then dirspecs.
    let l:identifiers = sort(filter(s:GetIdentifiers(), 'v:val =~ "\\V\\^" . escape(a:ArgLead, "\\")'))
    if empty(a:ArgLead) && ! empty(l:identifiers)
	return l:identifiers
    endif

    let l:dirspecs =
    \   map(
    \       filter(
    \           ingo#compat#glob(a:ArgLead . '*', 0, 1),
    \           'isdirectory(v:val)'
    \       ),
    \       'ingo#compat#fnameescape(ingo#fs#path#Combine(v:val, ""))'
    \   )

    return l:identifiers + l:dirspecs
endfunction

function! s:GetExistingMessageStores( messageStoreDirspec, targetBufNr )
    let l:bufValue = getbufvar(a:targetBufNr, 'MessageRecall_MessageStores')

    if l:bufValue is# ''
	let l:messageStores = (exists('g:MessageRecall_MessageStores') ? g:MessageRecall_MessageStores : [''])
    else
	let l:messageStores = l:bufValue
    endif

    return map(l:messageStores, 'MessageRecall#Buffer#ExtendMessageStore(a:messageStoreDirspec, v:val)')
endfunction
function! MessageRecall#Stores#Set( targetBufNr, messageStoreDirspec, isReplace, argument )
    if empty(a:argument)
	let l:messageStores = s:GetExistingMessageStores(a:messageStoreDirspec, a:targetBufNr)
	if empty(l:messageStores)
	    echo 'No configured message stores'
	else
	    echohl Title
	    echo 'Configured message stores'
	    echohl None
	    for l:messageStore in l:messageStores
		let l:dirspec = fnamemodify(l:messageStore, ':~:.')
		echo (empty(l:dirspec) ? '.' : l:dirspec)
	    endfor
	endif

	return 1
    endif


    let l:messageStores = s:GetConfiguredMessageStores()
    if has_key(l:messageStores, a:argument)
	let l:dirspec = l:messageStores[a:argument]
    elseif isdirectory(a:argument)
	let l:dirspec = a:argument
    else
	call ingo#err#Set('No such configured message store, and not an existing directory: ' . a:argument)
	return 0
    endif

    " Canonicalize to avoid adding duplicates.
    let l:dirspec = ingo#fs#path#Normalize(fnamemodify(l:dirspec, ':p'))

    if a:isReplace
	let l:newValue = [l:dirspec]
    else
	let l:newValue = filter(s:GetExistingMessageStores(a:messageStoreDirspec, a:targetBufNr), 'v:val !=# l:dirspec')
	call add(l:newValue, l:dirspec)
    endif
    call setbufvar(a:targetBufNr, 'MessageRecall_MessageStores', l:newValue)

    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
