An update of the current state of R3-GUI resizing, proposing some changes.

	Author: Ladislav Mecir

===Resizing

The resizing algorithm resizes graphic objects knowing their INIT-SIZE, MIN-SIZE and MAX-SIZE. This part hasn't changed for quite some time now.

===Autosizing

For panels like vpanels, hpanels, vgroups, and hgroups it is possible to calculate their INIT-SIZE, MIN-SIZE and MAX-SIZE dimensions using the known dimensions of their contents. The same holds for the dimensions of panel columns and rows.

This autosizing worked for quite some time as well, automatically calculating the needed INIT-SIZE, MIN-SIZE and MAX-SIZE of panels, their columns, and rows.

---Autosizing versus manual sizing

Unfortunately, we were warned by Bolek, that sometimes it was preferable to allow the user to set the panel dimensions directly (or, at least, choose the algorithm used to calculate the panel dimensions, which may be different in some cases) e.g. by manually moving a divider between panel columns, or using other methods.

---Allowing manual sizing, instead of autosizing, the current state

Therefore, we defined some variables like RESIZE = OFF (used to set the panel MIN-SIZE and MAX-SIZE to the same pair as INIT-SIZE in such a case, suppressing the panel's "ability" to resize, since such panels will not change their dimension), AUTO-SIZE = OFF (used to suppress autozing, i.e. to keep the values that were manually set).

The trouble is, that these variables have been proven insufficient by Bolek this week, showing examples, which don't behave expectedly, and don't allow a simple remedy.

There already were some iterations of the autosizing algorithm, reacting to Bolek's requests we found necessary to honor.

---Autosizing - proposed changes

Taking into account the number of iterations of the autosizing changes, the insufficiency of the current state, and the fact, that there is no guarantee a similar "evolutionary change" would be definitely sufficient, I propose a completely different, and hopefully much more flexible alternative as follows:

*all "autosized dimensions" will always be calculated, but using so-called "hint variables" (already implemented in case of panel columns, where Cyphre wanted three different algorithms and their combinations to be used for column size calculation), to explain, why it will work, notice, that one of the possible algorithms used shall be the 'keep algorithm meaning, that the current value(s) are kept, instead of being truly recalculated
*the user, instead of setting the INIT-SIZE, MIN-SIZE and MAX-SIZE attributes, that will be "always calculated" for panels, their rows and columns, shall, in case of hpanels, vpanels, hgroups, vgroups, and in case of their rows/columns always use the "hint variables", which will allow him to either specify the algorithm used to calculate the corresponding size attribute, or even specify the value to use "directly" to copy to the size attribute from the hint variable

+++Advantages

This proposal will allow using and specifying of any number of different autosizing algorithms, as well as direct setting of all size attributes the user wishes to set directly, so, this is a "future proof" approach.

+++Disadvantages

Since the flexibility is so high, in some cases, the user might find out he is able to set more attributes than he even cares to know. Nevertheless, due to our experiences with requests to allow manual settings of "unexpected attributes", this looks like the only proper way to go.

===Resizing quirks found recently

Originally, the INIT-SIZE of any object was assumed to be in the range between the object's MIN-SIZE and MAX-SIZE. Due to the requirements/results of manual resizing, it occurred to be necessary to relax the relation, allowing the INIT-SIZE to be smaller than MIN-SIZE, or greater than MAX-SIZE, where appropriate. This may especially occur during manual resizing (divider moving), where the INIT-SIZE is recalculated for an object, which may already be resized (minified or magnified several times). In such case, the recalculated INIT-SIZE cannot be guaranteed to stay between the object's MIN-SIZE and MAX-SIZE values.

---Proposed resizing change

It appears to be necessary to relax the relation between MIN-SIZE, MAX-SIZE and INIT-SIZE, thus, using a slightly different algorithm not relying on INIT-SIZE being in the specified range.

The last research shows, that the algorithm will stay very similar, although a bit more complicated. The memory consumption will remain the same, the speed is expected to be a bit smaller, but not in a substantial way.

The end.