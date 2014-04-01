code-slices.vim
===============

The code-slices plugin is created to solve the need of collecting blocks of
code. It was started as a personal project to speed up the learning curve of
new frameworks and languages by reusing previously typed/copypasted fragmets
of code directly from vim. It's different from snippets plugins like ultisnips,
snipmate and xptemplate because It show you the complete block of code in a
special window with syntax higlighting and beacause it's not in its purposes
to do inplace transformations like snippets plugins do. Its main purpose is to
be a tool to collect code slices in a quick, easy and even fun way so, it can
help you to learn new tools by reducing the time you have too search in
documentation and to collect and reuse boilerplate code so you don't have to
type or copypaste it more than once

### Installing

Because code-slices is pathogen compatible you can just clone the repo in your
bundle plugin:


Similar steps should be performed to use it with Vundle

### First Steps

The default configuration of code-slices is to search for the slices's
directory in your .vim directory in the structure:

        $HOME
        |~.vim
        | |-slices
        | `-{filetype}.slices

You can change the default slices directory by using the global variable
g:slices\_preferred\_path for example I'm storing the slices in the path
$HOME/code-slices/slices/ with the configuration:

        let g:slices_preferred_path=expand('$HOME') . '/code-slices'

Remember that the plugin automatically adds 'slices' to the path

### Using the plugin

The first interaction you should have with the plugin should be to create a
Slice by using a visual selection. For example to save the following sample of
shellscript as a slice:

        if [ -z "$a\_variable"]; then
          echo "This is empty"
        fi

You can start Visual mode in the first line and select all the three lines.
After that by using the command:

        :CreateSlice zero length var

It results in a new slice added to the file `sh.slices` In the default group
named pending. Then you can see the just create slice in the slices window
just by using the `:ShowSlices` command. If you have more than one slice
created, you can navigate them by using the `<Tab>` and `<BS>` and insert them
using the `<Space>` or the `<CR>` keys

### Writing slices
In general you should not be writing the slices you want to use, those slices
are created by executing the CreateSlice and CreateFluentSlice commands,
however you need to manually edit the slices files to clasify them on groups

The syntax to create slices is very simple. The slices files just contains
source code for the filetype it belongs and the slices and groups declaration
I.E. When you do not have slices and just create example of the previous slice
the slices files look like the following

        Group pending
        Slice zero length var
          if [ -z "$a\_variable"]; then
            echo "This is empty"
          fi

A group starts where is declared and ends when other group starts, when there
are two consecutive empty lines or when the last line in the file is reached


Plugin by Roberto Bernab&eacute; Distributed under the same terms as Vim
itself.  See `:help license`.
