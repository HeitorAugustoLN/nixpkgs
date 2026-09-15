/* register-darwin-emacs-fonts: register font files with Core Text.

   Used by the emacsWithPackages wrapper on Darwin, where the NS port finds
   fonts through Core Text only: unlike fontconfig, Core Text scans no
   environment variables, so wrapped fonts must be registered explicitly to
   be usable by Emacs.

   Fonts are registered in kCTFontManagerScopeProcess, which is visible to
   the registering process only: this process then exec's Emacs (see
   wrapper.sh), and since a process-scoped registration is keyed to the
   process -- not the executable -- it survives the exec.  The fonts are
   therefore visible to exactly this Emacs instance: no other application
   sees them, Font Book does not list them, and nothing is copied into the
   font directories or otherwise written to disk.  (The persistent scopes
   would keep the registered locations across sessions, leaving them
   pointing at garbage-collected store paths.)  Registration is idempotent,
   so invoking this on every Emacs start is cheap.

   Registration errors (non-font files, already-registered fonts, ...) are
   deliberately ignored: this runs before Emacs starts, and must never
   prevent it from starting.  */

#include <CoreText/CoreText.h>

#include <dirent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>

static const char *const fontExtensions[] = {
  ".ttf", ".otf", ".ttc", ".otc", ".dfont",
};

static bool
has_font_extension (const char *name)
{
  const size_t length = strlen (name);

  for (size_t i = 0; i < sizeof fontExtensions / sizeof fontExtensions[0];
       i++)
    {
      const char *extension = fontExtensions[i];
      const size_t extensionLength = strlen (extension);

      if (length >= extensionLength
          && strcasecmp (name + length - extensionLength, extension) == 0)
        return true;
    }

  return false;
}

static void
register_font (const char *path)
{
  CFURLRef url = CFURLCreateFromFileSystemRepresentation (
    kCFAllocatorDefault, (const UInt8 *) path, strlen (path), false);

  if (url != NULL)
    {
      CFErrorRef error = NULL;

      CTFontManagerRegisterFontsForURL (url, kCTFontManagerScopeProcess,
                                        &error);
      if (error != NULL)
        CFRelease (error);

      CFRelease (url);
    }
}

static void
register_tree (const char *dir, unsigned int depth)
{
  DIR *dirp = opendir (dir);

  if (dirp == NULL)
    return;

  struct dirent *entry;
  while ((entry = readdir (dirp)) != NULL)
    {
      if (entry->d_name[0] == '.')
        continue;

      const size_t pathSize = strlen (dir) + strlen (entry->d_name) + 2;
      char *path = malloc (pathSize);

      if (path == NULL)
        continue;

      snprintf (path, pathSize, "%s/%s", dir, entry->d_name);

      /* `lndir' mirrors directory trees with symlinks, so symlinked
         entries must be followed both to recurse and to register.  */
      bool isDir;
      if (entry->d_type == DT_DIR)
        isDir = true;
      else if (entry->d_type == DT_UNKNOWN)
        {
          struct stat st;
          isDir = stat (path, &st) == 0 && S_ISDIR (st.st_mode);
        }
      else
        isDir = false;

      if (isDir)
        {
          if (depth > 0)  /* guard against pathological structures */
            register_tree (path, depth - 1);
        }
      else if (has_font_extension (entry->d_name))
        register_font (path);

      free (path);
    }

  closedir (dirp);
}

int
main (int argc, char **argv)
{
  /* Usage: register-darwin-emacs-fonts FONTSDIR... -- PROGRAM [ARG...]  */
  int i;
  for (i = 1; i < argc && strcmp (argv[i], "--") != 0; i++)
    register_tree (argv[i], 8);

  if (i >= argc - 1 || argv[i + 1] == NULL)
    {
      fputs ("usage: register-darwin-emacs-fonts FONTSDIR... -- PROGRAM [ARG...]\n",
             stderr);
      return EXIT_FAILURE;
    }

  /* Replace this process with PROGRAM; the process-scoped registrations
     made above are keyed to the process and come along for the ride.  */
  execvp (argv[i + 1], &argv[i + 1]);
  perror ("execvp");
  return EXIT_FAILURE;
}
