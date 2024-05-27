CAMLC=$(BINDIR)ocamlc
CAMLDEP=$(BINDIR)ocamldep
CAMLLEX=$(BINDIR)ocamllex
CAMLYACC=$(BINDIR)ocamlyacc
# COMPFLAGS=-w A-4-6-9 -warn-error A -g
COMPFLAGS=

EXEC = loop

# Fichiers compilés, à produire pour fabriquer l'exécutable
SOURCES = memory.ml sem.ml loop.ml
GENERATED = lexeur.ml parseur.ml parseur.mli
MLIS =
OBJS = ast.ml $(GENERATED:.ml=.cmo) $(SOURCES:.ml=.cmo)

# Building the world
all: $(EXEC)

$(EXEC): $(OBJS)
	$(CAMLC) $(COMPFLAGS) $(OBJS) -o $(EXEC)

.SUFFIXES:
.SUFFIXES: .ml .mli .cmo .cmi .cmx
.SUFFIXES: .mll .mly

.ml.cmo:
	$(CAMLC) $(COMPFLAGS) -c $<

.mli.cmi:
	$(CAMLC) $(COMPFLAGS) -c $<

.mll.ml:
	$(CAMLLEX) $<

.mly.ml:
	$(CAMLYACC) $<

# Clean up
clean:
	rm -f *.cm[io] *.cmx *~ .*~ *.o
	rm -f $(GENERATED)
	rm -f $(EXEC)

# Dependencies
depend: $(SOURCES) $(GENERATED) ast.ml $(MLIS)
	$(CAMLDEP) $(SOURCES) $(GENERATED) ast.ml $(MLIS) > .depend

include .depend

