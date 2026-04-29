Can you add a button "reload" right to the language button, compliant to docs/design_system.md

With "reload" icon. It should run reshuffle random categories list (you should write a doc of how now the categories are handled in the app into the docs folder) And it should add fresh recipies for those categories from API (via mahallem buffer memory and translation hub) (you should add a doc into the docs folder how it works now)

The buffer memory for translation in mahallem (with following fetching the phone app memory (of 500+ recipies translated) from this mahallem buffer memory) may be 1 - 1.5 Gb, with "first in last out" when limit is exceeded.

Can you write a doc for this system into the docs folder, investigate current implementation and check compliance, and recommend actions to do to adjust it to the described above, if required. And add the button described above.