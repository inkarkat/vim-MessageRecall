" MessageRecall/MappingsAndCommands.vim: Setup for message buffer and preview.
"
" DEPENDENCIES:
"   - ingo/err.vim autoload script
"   - ingo/escape/command.vim autoload script
"   - MessageRecall.vim autoload script
"   - MessageRecall/Buffer.vim autoload script
"
" Copyright: (C) 2012-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.008	15-Jul-2014	Undo the duplication of
"				b:MessageRecall_MessageStores and instead just
"				pass a:targetBufNr into
"				MessageRecall#Buffer#OpenNext().
"   1.10.007	14-Jul-2014	Also pass the messageStores configuration to
"				MessageRecall#MappingsAndCommands#PreviewSetup()
"				and duplicate the config to each previewed
"				message buffer.
"				Replace EditSimilar#Next#Open() with
"				MessageRecall#Buffer#OpenNext().
"   1.03.006	01-Apr-2014	Adapt to changed EditSimilar.vim interface that
"				returns the success status now.
"				Abort on error for own plugin commands.
"   1.02.005	09-Aug-2013	Allow to change / disable the defined mappings
"				by using intermediate <Plug>-mappings. This also
"				prevents escaping issues with my buffer-local
"				UniversalIteratorMapping iteration mode.
"				Use ingo#escape#command#mapescape().
"				Trigger User autocmds, e.g. to allow to easily
"				define alternative mappings for <C-p> / <C-n>,
"				as there's no fixed filetype one could use here.
"   1.02.004	05-Aug-2013	Pass range and whenRangeNoMatch options to the
"				<C-p> / <C-n> mappings, too.
"				Mark previewed stored messages with
"				b:MessageRecall_Buffer to be able to recognize
"				them in MessageRecall#Buffer#Replace().
"   1.01.003	12-Jul-2012	The :MessageRecall command in the message buffer
"				needs access to the a:whenRangeNoMatch option.
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
    execute printf('command! -buffer -bang MessageRecall if ! MessageRecall#Buffer#PreviewRecall(<q-bang>, %d) | echoerr ingo#err#Get() | endif', a:targetBufNr)
    execute printf('command! -buffer       -count=1 -nargs=? -complete=customlist,%s MessageView if ! MessageRecall#Buffer#Preview(1, <count>, <q-args>, %s, %d) | echoerr ingo#err#Get() | endif', MessageRecall#GetFuncrefs(l:messageStoreDirspec)[1], string(l:messageStoreDirspec), a:targetBufNr)

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

    if v:version == 703 && has('patch438') || v:version > 703
	silent doautocmd <nomodeline> User MessageRecallPreview
    else
	silent doautocmd              User MessageRecallPreview
    endif
endfunction

function! MessageRecall#MappingsAndCommands#MessageBufferSetup( messageStoreDirspec, range, whenRangeNoMatch, CompleteFuncref )
    let l:targetBufNr = bufnr('')

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

    if v:version == 703 && has('patch438') || v:version > 703
	silent doautocmd <nomodeline> User MessageRecallBuffer
    else
	silent doautocmd              User MessageRecallBuffer
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
