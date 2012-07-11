" MessageRecall/MappingsAndCommands.vim: Setup for message buffer and preview.
"
" DEPENDENCIES:
"   - EditSimilar/Next.vim autoload script
"   - MessageRecall.vim autoload script
"   - MessageRecall/Buffer.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.002	19-Jun-2012	Define :MessageView command in preview buffer,
"				too, as a more discoverable alternative to
"				CTRL-P / CTRL-N navigation.
"				Prune unnecessary a:range argument.
"				Pass in a:targetBufNr to
"				MessageRecall#Buffer#Preview(), now that it is
"				also used from inside the preview window, and do
"				the same to MessageRecall#Buffer#Replace() for
"				consistency.
"   1.00.001	19-Jun-2012	file creation

function! MessageRecall#MappingsAndCommands#PreviewSetup( targetBufNr, filetype )
    let l:messageStoreDirspec = expand('%:p:h')
    execute printf('command! -buffer -bang MessageRecall call MessageRecall#Buffer#PreviewRecall(<q-bang>, %d)', a:targetBufNr)
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessageView call MessageRecall#Buffer#Preview(1, <count>, <q-args>, %s, %d)', MessageRecall#GetFuncrefs(l:messageStoreDirspec)[1], string(l:messageStoreDirspec), a:targetBufNr)

    let l:command = 'view +' . substitute(escape(MessageRecall#Buffer#GetPreviewCommands(a:targetBufNr, a:filetype), ' \'), '|', '<Bar>', 'g')
    execute printf('nnoremap <silent> <buffer> <C-p> :<C-u>call EditSimilar#Next#Open(%s, 0, expand("%%:p"), v:count1, -1, MessageRecall#Glob())<CR>', string(l:command))
    execute printf('nnoremap <silent> <buffer> <C-n> :<C-u>call EditSimilar#Next#Open(%s, 0, expand("%%:p"), v:count1,  1, MessageRecall#Glob())<CR>', string(l:command))
endfunction

function! MessageRecall#MappingsAndCommands#MessageBufferSetup( messageStoreDirspec, range, CompleteFuncref )
    let l:targetBufNr = bufnr('')

    execute printf('command! -buffer -bang -count=1 -nargs=? -complete=customlist,%s MessageRecall  call MessageRecall#Buffer#Recall(<bang>0, <count>, <q-args>, %s, %s)', a:CompleteFuncref, string(a:messageStoreDirspec), string(a:range))
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessageView call MessageRecall#Buffer#Preview(1, <count>, <q-args>, %s, %d)', a:CompleteFuncref, string(a:messageStoreDirspec), l:targetBufNr)

    execute printf('nnoremap <silent> <buffer> <C-p> :<C-u>call MessageRecall#Buffer#Replace(1, v:count1, %s, %d)<CR>', string(a:messageStoreDirspec), l:targetBufNr)
    execute printf('nnoremap <silent> <buffer> <C-n> :<C-u>call MessageRecall#Buffer#Replace(0, v:count1, %s, %d)<CR>', string(a:messageStoreDirspec), l:targetBufNr)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
