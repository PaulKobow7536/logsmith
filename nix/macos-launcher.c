#include <Python.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int prepend_env(const char *name, const char *value)
{
    const char *current = getenv(name);
    if (current == NULL || current[0] == '\0')
        return setenv(name, value, 1);

    size_t size = strlen(value) + strlen(current) + 2;
    char *combined = malloc(size);
    if (combined == NULL)
        return -1;

    snprintf(combined, size, "%s:%s", value, current);
    int result = setenv(name, combined, 1);
    free(combined);
    return result;
}

int main(int argc, char **argv)
{
    if (setenv("PYTHONHOME", "@pythonHome@", 1) != 0 ||
        setenv("QT_PLUGIN_PATH", "@qtPluginPath@", 1) != 0 ||
        setenv("QML_IMPORT_PATH", "@qmlImportPath@", 1) != 0 ||
        prepend_env("PYTHONPATH", "@pythonPath@") != 0 ||
        prepend_env("PATH", "@runtimePath@") != 0) {
        perror("Logsmith: could not configure the runtime environment");
        return 1;
    }

    char **python_argv = calloc((size_t)argc + 2, sizeof(*python_argv));
    if (python_argv == NULL) {
        perror("Logsmith: could not allocate Python arguments");
        return 1;
    }

    python_argv[0] = argv[0];
    python_argv[1] = "@scriptPath@";
    for (int i = 1; i < argc; ++i)
        python_argv[i + 1] = argv[i];

    int result = Py_BytesMain(argc + 1, python_argv);
    free(python_argv);
    return result;
}
