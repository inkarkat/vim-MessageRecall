" MessageRecall/MappingsAndCommands.vim: Setup for message buffer and preview.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2020 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:CommonSetup( targetBufNr, messageStoreDirspec, CompleteFuncref )
    execute printf('command! -buffer -bar -count=0 MessageList             if ! MessageRecall#Buffer#List(%d, %s, <count>) | echoerr ingo#err#Get() | endif', a:targetBufNr, string(a:messageStoreDirspec))
    execute printf('command! -buffer -bar -count=0 -nargs=* MessageGrep    if ! MessageRecall#Buffer#Grep(%d, %s, <count>, <q-args>) | echoerr ingo#err#Get() | endif', a:targetBufNr, string(a:messageStoreDirspec))
    execute printf('command! -buffer -bar -count=0 -nargs=+ MessageVimGrep if ! MessageRecall#Buffer#VimGrep(%d, %s, <count>, <q-args>) | echoerr ingo#err#Get() | endif', a:targetBufNr, string(a:messageStoreDirspec))

    execute printf('command! -buffer -bang -nargs=? -complete=customlist,MessageRecall#Stores#Complete MessageStore if ! MessageRecall#Stores#Set(%d, %s, <bang>0, <q-args>) | echoerr ingo#err#Get() | endif', a:targetBufNr, string(a:messageStoreDirspec))
    execute printf('command! -buffer -bang -count=0 -nargs=? -complete=customlist,%s MessagePrune if ! MessageRecall#Buffer#Prune(%d, %s, <bang>0, <count>, <q-args>) | echoerr ingo#err#Get() | endif', a:CompleteFuncref, a:targetBufNr, string(a:messageStoreDirspec))
endfunction

function! MessageRecall#MappingsAndCommands#PreviewSetup( targetBufNr, filetype )
    let l:messageStoreDirspec = expand('%:p:h')
    let l:CompleteFuncref = MessageRecall#GetFuncrefs(l:messageStoreDirspec)[1]
    call s:CommonSetup(a:targetBufNr, l:messageStoreDirspec, l:CompleteFuncref)

    execute printf('command! -buffer -bang MessageRecall if ! MessageRecall#Buffer#PreviewRecall(<q-bang>, %d) | echoerr ingo#err#Get() | endif', a:targetBufNr)
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessageView if ! MessageRecall#Buffer#Preview(1, <count>, <q-args>, %s, %d) | echoerr ingo#err#Get() | endif', l:CompleteFuncref, string(l:messageStoreDirspec), a:targetBufNr)

    let l:command = 'view +' . ingo#escape#command#mapescape(escape(MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, a:filetype), ' \'))
    execute printf('nnoremap <silent> <buffer> <Plug>(MessageRecallPreviewPrev) :<C-u>if ! MessageRecall#Buffer#OpenNext(%s, %s, "", expand("%%:p"), v:count1, -1, %d)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>', string(l:messageStoreDirspec), string(l:command), a:targetBufNr)
    execute printf('nnoremap <silent> <buffer> <Plug>(MessageRecallPreviewNext) :<C-u>if ! MessageRecall#Buffer#OpenNext(%s, %s, "", expand("%%:p"), v:count1,  1, %d)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>', string(l:messageStoreDirspec), string(l:command), a:targetBufNr)
    if ! hasmapto('<Plug>(MessageRecallPreviewPrev)', 'n')
	nmap <buffer> <C-p> <Plug>(MessageRecallPreviewPrev)
    endif
    if ! hasmapto('<Plug>(MessageRecallPreviewNext)', 'n')
	nmap <buffer> <C-n> <Plug>(MessageRecallPreviewNext)
    endif

    let b:MessageRecall_Buffer = 1
    call ingo#event#TriggerCustom('MessageRecallPreview')
endfunction

function! MessageRecall#MappingsAndCommands#MessageBufferSetup( messageStoreDirspec, range, whenRangeNoMatch, CompleteFuncref )
    let l:targetBufNr = bufnr('')

    call s:CommonSetup(l:targetBufNr, a:messageStoreDirspec, a:CompleteFuncref)

    execute printf('command! -buffer -bang -count=1 -nargs=? -complete=customlist,%s MessageRecall  if ! MessageRecall#Buffer#Recall(<bang>0, <count>, <q-args>, %s, %s, %s) | echoerr ingo#err#Get() | endif', a:CompleteFuncref, string(a:messageStoreDirspec), string(a:range), string(a:whenRangeNoMatch))
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessageView    if ! MessageRecall#Buffer#Preview(1, <count>, <q-args>, %s, %d) | echoerr ingo#err#Get() | endif', a:CompleteFuncref, string(a:messageStoreDirspec), l:targetBufNr)

    execute printf('nnoremap <silent> <buffer> <Plug>(MessageRecallGoPrev) :<C-u>call MessageRecall#Buffer#Replace(1, v:count1, %s, %s, %s, %d)<CR>', string(a:messageStoreDirspec), string(a:range), string(a:whenRangeNoMatch), l:targetBufNr)
    execute printf('nnoremap <silent> <buffer> <Plug>(MessageRecallGoNext) :<C-u>call MessageRecall#Buffer#Replace(0, v:count1, %s, %s, %s, %d)<CR>', string(a:messageStoreDirspec), string(a:range), string(a:whenRangeNoMatch), l:targetBufNr)
    if ! hasmapto('<Plug>(MessageRecallGoPrev)', 'n')
	nmap <buffer> <C-p> <Plug>(MessageRecallGoPrev)
    endif
    if ! hasmapto('<Plug>(MessageRecallGoNext)', 'n')
	nmap <buffer> <C-n> <Plug>(MessageRecallGoNext)
    endif

    call ingo#event#TriggerCustom('MessageRecallBuffer')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
