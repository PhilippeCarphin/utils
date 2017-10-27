SOURCE = $(wildcard *.c)
EXEC = $(SOURCE:.c=.out)
TEST_ARGS = $(SOURCE)
PROJ_COMPILER = $(CC)

all:

$(EXEC):$(SOURCE)
	$(PROJ_COMPILER) $^ -o $@

.PHONY:test vars
test:$(EXEC)
	./$(EXEC) $(TEST_ARGS)

vars:
	@echo "SOURCE : $(SOURCE)"
	@echo "EXEC : $(EXEC)"
	@echo "TEST_ARGS : $(TEST_ARGS)"
	@echo "PROJECT_COMPILER : $(PROJ_COMPILER)"
