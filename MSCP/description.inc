These are the MSCP emulator files, they are here to check assembler syntax, for the
moment the code is just assembled and included in the hex file but not executed

From the RQDX3 source code
--------------------------

There are the following jobs

1. main() in source code main.c

Main looks if there is a DUP program and if yes executes it. Then it waits for 1000ms
and decrements the host access timer, if the host access timer reaches zero it is
considered to be a fatal error of type "pe_hat"


2. poll() in source code uqsspm.mc

This job tries to fetch a new packet from the command ring, if there is a command
packet it copies the content to the local command packet queue of the appropriate
work job, once the command ring is empty it waits for the IPR interrupt

It recognizes two error conditions

- the packet has invalid packet type "pe_pie", protocol incompatibility error
- the packet has invalid connection "pe_ici", illegal connection identifier, i.e. it
 is neither a DUP or MSCP packet
 
Processing of commands is done in do_mscp() in source code mscp.c 

poll() is actually the only routine that is directly triggered by the IPR interrupt
request and just dispatches the commands to the appropriate work() job. In our case
there is no need for multiple work jobs as we don't have multiple disk drives and
even if we will support multiple units there is still only one SD-CARD. Hence there
is no chance that we can do overlapped processing of SEEK and DATA transfer.


 
3. scan() in source code scan.c
 
every second updates the status of the UCBs


4.  work() in source code work.c

This job is run as many times as there are units, they actually execute the
commands 

5. time() in source code time.c

This task runs every second and handles the timers. There are exactly three
timers in the RQDX3 system, all time-outs are related to the HD controller chip
9224. Hence in our case they are not required at all as there is no such thing
as a 9224 time-out. We only need to cover SD-CARD time-outs. However this will
be handled directly by the SD-CARD-IO module

5.1. Time-Out routines in 9224.c

sd_tmo() select drive time-out
mo_tmo() motor on time-out
cd_tmo() command done time-out

MSCP Emulator
=============

As with the RLV12 Emulator we will support up to 4 units.

CREDIT will be 15 

No queues for different units, all commands are processed sequentually. 

List of Jobs
------------

The MSCP Emulator will have the following jobs

1. sdcard()

The standard insert/remove SD-CARD detection and mounting

2. poll()

The MSCP Emulator

3. main()

The command line interface

4. scan()

Update UCBs and host timeout



Lebenslauf Yvonne Bertha Gloor Bonhôte
--------------------------------------

Yvonne Bertha wurde am 25.04.1930 in Aarau geboren. Ihre Eltern waren
Jeanne Bonhôte (*1906 - +1994) und Arnold Gloor (*1899 - +1968). Es waren
schwierige Zeiten in die Yvonne hinein geboren wurde. Kurz nach ihrer Geburt
war die grosse Weltwirtschaftskrise und die Eltern immer auf der Suche nach
neuen Erwerbsmöglichkeiten mussten oft umziehen. In dieser schwierigen Zeit
kam auch ihr Bruder Arnold Georg Gloor 1936 auf die Welt. Aber auch nachdem
die Weltwirtschaftskrise überwunden war blieb das Glück nicht lange auf der
Seite der Familie. Der 2te Weltkrieg brach aus und damit der nächste 
Schicksalsschlag für die Familie. In dieser Zeit gab es noch keinen vernünftigen
Erwerbsersatz und die Dienstzeit schlug finanziell voll auf die Familien der
Dienstleistenden durch. Ein trauriges Kapitel der Schweizer Geschichte.
Kurz nach dem Ende des Kriegs, vor allem durch die unermüdlichen Bemühungen
ihrer Mutter Jeanne, konnte die Familie ein Eigenheim in Zuchwil ihr eigen
nennen, an der Unterfeldstrasse 7. Dieses von Jeanne als "mys hüüsli" bezeichnete
Haus steht heute (Google Street View 2013) noch und ist fast unverändert erhalten. 
Sogar der Apfelbaum (Suurgrauech) und der Kirschbaum (Weichsel) und der Tuya Hag, den
Granpapa (der Vater) so sehr geliebt hatte sind in Goolge Street View noch sichtbar.

Arnold Gloor fand in Zuchwil endlich eine seiner Ausbildung gerechte Anstellung
als Maschineningenieur bei der Firma Scintilla. 

Nach einem Welschlandjahr und einem längeren Landdienst besuchte Yvonne mit
18 das Kindergartenlehrerseminar in Solothurn. Dort lernte sie auch verschiedene Seminarteil-
nehmer kennen unter ihnen Elisabeth Hofstetter (Allianznamen) und Vreni Schranz Ledigname).
Durch Vreni lernte sie ihren zukünftigen Ehemann Peter August Schranz kennen welchen
sie im Jahre 1957 heiratete. Doch davor arbeitete sie mehrere Jahre als Kindergärtnerin
in Zuchwil/Solothurn

Das Ehepaar Schranz-Gloor zog nach Zug wo Peter Schranz, diplomierter Physiker, bei
Landis&Gyr arbeitete. Im Jahr 1958 kam ihr estes Kind, Peter Arnold Schranz, auf
die Welt. Im Jahr 1960 zog die junge Familie nach Oberwil ZG in eine schön gelegen
Wohnung an der Widenstrasse 22.

Yvonne erzählte noch oft, dass sie danach immer als Frau Doktor angesprochen wurde,
weil die Wohnungen als sehr teuer galten und man davon ausging, dass sich nur Doktoren
oder Professoren eine so teuer Wohnung leisten konnte.

Die Wohnung hatte einen wunderschönen Blick auf den Zugersee. 

Im November 1960 kam dann das zweite Kind, Felix Georg und im Jahr 1992 das dritte
Kind Susanne Yvonne Bertha Schranz in Zug auf die Welt. 

Jeden Sonntag verbrachte die Familie in der näheren Umgebung, heute würde man sagen
grünes Naherholungsgebiet. Der Zuger Berg war der Hausberg, aber auch auf die Rigi
wurden immer wieder Exkursionen gemacht. Das jüngste Kind jeweils im "gebirgsgängigen"
Kinderwagen. Wandern, Pilze und Waldbeeren waren ein Hobby dem sie und ihr Mannlange 
treu blieb und an ihre Kinder weitergab.

In dieser Zeit war Yvonne mit der Familie ausgelastet. Damals war es noch üblich, dass
der Mann mit seinem Verdienst die ganze Familie unterhalten konnte. Yvonne hat sehr
viel mit den Kinder unternommen und vor allem viel gebastelt. Vor allem auch mit
Gegenstände die man während der Wanderung im Wald gesammelt hat, mit Kastanien,
Nüssen. 

Im Jahr 1965 wechselte ihr Mann die Arbeit von der Landis&Gyr zur Suisse-Elektra
als Projektleiter, die Familie zog im Jahr 1966 nach und bezogen eine Wohnung in 
Arlesheim, im Lee 24.

Als diplomierte Kindergärtnerin arbeitete sie öfters als Aushilfe in Arlesheim, wenn
eine Kindergärtnerin ausfiel. Was sehr oft um die Weihnachtszeit vorkam, wie Yvonne
gerne bemerkte. Die Gründe kann man sich wohl ausdenken. Dank dieser Tätigkeit und
dank den vielen jungen Familien die in der damals gerade aufgebauten Siedlung im Lee
ihr neues Zuhause fanden fand die Familie schnell Anschluss. Im Jahre 1968 bezog
die Familie eine Eigentumswohnung im gerade fertiggestellten Haus 28 der Siedlung.
1970 kam ihr viertes Kind Urs Lukas auf die Welt. Leider verschlechterte sich die 
wirtschaftliche Situation in dieser Zeit stark und Peter verlor seine Stelle. 
Peter fand aber relativ rasch eine neue Stelle bei BBC in Turgi. 

Nach und nach verliessen die Kinder das Zuhause, und Yvonne und Peter lebten
alleine in Arlesheim. Aber nicht wirklich alleine. Die Kinder wohnten in Basel
und regelmässig nahmen sie an den immer noch wöchentlich am Sonntag stattfindenen
Wanderungen und Sammelaktionen, und anderen Exkursionen Teil. Sehr schnell wurde
die Wohnung in Arlesheim der Ort für den Mittagstisch der ersten Enkel und die 
Kinder zogen wieder zurück nach Arlesheim. Der Zufall wollte es, dass alle in
Arlesheim ein Eigenheim bauten.

Im Jahre 2011 verstarb ihr Ehemann und von nun an lebte sie alleine in der Wohnung
Im Lee 28 bis sie auf eigenen Wunsch im August 2018 in ein Pflegeheim zog. Zuerst in
Aesch BL im Alterszentrum "Im Brüel" wo sie ein Zweierzimmer mit einer weiteren
Bewohnerin teilen musste und danach ab März 2019 im Pflegeheim der Alterssiedlung
"Obesunne" in Arlesheim.

Die letzten Jahre empfand Yvonne als sehr anstrengend. Verschiedene gesundheitliche
Beschwerden veranlassten sie immer wieder davon zu sprechen, dass sie gehen möchte.

Trotzdem bin ich überzeugt, dass Yvonne trotz dieser Herausforderungen gerne gelebt
hat und miterleben konnte wie die Kinder und Enkelkinder sich entwickelten und sie
am Schluss auch ihren ersten Urenkel in die Arme nehmen konnte.

Im September 2024 erlitt sie einen Schlaganfall. Trotz sofortiger Intervention und
Operation erholte sie sich nicht und ihr Zustand verschlechterte sich rasch. 12 Tage
später, am 26.09.2024, verstarb sie.

Lebenslauf Peter August Schranz
-------------------------------

Peter August Schranz wurde am 11.04.1927 in ... geboren als jüngstes Kind von 
August Schranz und Ida Schranz, geborene Leibundgut. Peter war ein verträumtes
aber sehr intelligentes Kind. Seine Geschwister waren Käthi, Robert und Vreni.

Er besuchte das Gymnasium in Solothurn wo seine Eltern ein Geschäft für Velos und
Nähmaschinen an der Schaalgasse hatten.

Peter war ein guter Schüler und musikalisch begabt, er hatte wohl ein absolutes
Gehör. Die finanziellen Möglichkeiten der Familie waren beschränkt und entsprechend
wurden seine Fähigkeiten nicht speziell gefördert.

Trotz dieser Hürden hat Peter Physik studiert und mit einem Diplom abgeschlossen, 
heute würde man sagen "Master". Er war Mitglied der Stundentenverbindung 
Wengia Solodorensis (am 8.11.1947 wurde er, v/o Yoghi, an der 49. Generalversammlung
in die Alt-Wengia aufgenommen)


