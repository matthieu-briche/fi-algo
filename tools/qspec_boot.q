/ Remplace l'ajout à q.q demandé par qutil : charge bootstrap.q depuis $QPATH, puis le lanceur qspec
{
 pathSep:$["w" ~ first string .z.o;";";":"];
 .utl.QPATH: hsym each `$pathSep vs getenv x;
 bootstrap: b first where not 0 = (count key@) each b:` sv' .utl.QPATH,'`bootstrap.q;
 system "l ", 1 _ string bootstrap;
 }[`QPATH]

system "l ",getenv[`QPATH],"/../qspec/app/spec.q"