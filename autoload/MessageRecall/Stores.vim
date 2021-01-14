" MessageRecall/Stores.vim: Choosing the message stores.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2014-2021 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

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
function! s:SortByLastUpdatedMessageStore( m1, m2 )
    return ingo#collections#FileModificationTimeSort(a:m1[1], a:m2[1])
endfunction
function! MessageRecall#Stores#Complete( ArgLead, CmdLine, CursorPos )
    " Initially offer only identifiers from the configuration. If there's a lead
    " (or no identifiers), complete first identifiers and then dirspecs.
    let l:identifiers =
    \   map(
    \       sort(
    \           filter(
    \               items(s:GetConfiguredMessageStores()),
    \               'v:val[0] =~ "\\V\\^" . escape(a:ArgLead, "\\")'
    \           ),
    \           's:SortByLastUpdatedMessageStore'
    \       ),
    \       'v:val[0]'
    \   )
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
function! MessageRecall#Stores#Set( targetBufNr, messageStoreDirspec, subDirForUserProvidedDirspec, isReplace, argument )
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
    if a:argument =~# '^\d\+$'
	let l:store = get(sort(items(l:messageStores), 's:SortByLastUpdatedMessageStore'), str2nr(a:argument) - 1, '')
	if empty(l:store)
	    call ingo#err#Set(printf('Only %d message store%s available', len(l:messageStores), (len(l:messageStores) == 1 ? '' : 's')))
	    return 0
	endif
	let l:dirspec = l:store[1]
    elseif has_key(l:messageStores, a:argument)
	let l:dirspec = l:messageStores[a:argument]
    elseif ! empty(a:subDirForUserProvidedDirspec) && isdirectory(ingo#fs#path#Combine(a:argument, a:subDirForUserProvidedDirspec))
	let l:dirspec = ingo#fs#path#Combine(a:argument, a:subDirForUserProvidedDirspec)
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

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
