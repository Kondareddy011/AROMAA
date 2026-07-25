#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"aroma", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

extern "C" {
    void* __std_find_trivial_1(void* first, void* last, unsigned char val) {
        unsigned char* p = (unsigned char*)first;
        unsigned char* end = (unsigned char*)last;
        while (p < end) {
            if (*p == val) return p;
            p++;
        }
        return last;
    }

    void* __std_find_trivial_2(void* first, void* last, unsigned short val) {
        unsigned short* p = (unsigned short*)first;
        unsigned short* end = (unsigned short*)last;
        while (p < end) {
            if (*p == val) return p;
            p++;
        }
        return last;
    }

    void* __std_find_trivial_4(void* first, void* last, unsigned int val) {
        unsigned int* p = (unsigned int*)first;
        unsigned int* end = (unsigned int*)last;
        while (p < end) {
            if (*p == val) return p;
            p++;
        }
        return last;
    }

    void* __std_find_trivial_8(void* first, void* last, unsigned long long val) {
        unsigned long long* p = (unsigned long long*)first;
        unsigned long long* end = (unsigned long long*)last;
        while (p < end) {
            if (*p == val) return p;
            p++;
        }
        return last;
    }

    void* __std_min_element_8(void* first, void* last) {
        unsigned long long* p = (unsigned long long*)first;
        unsigned long long* end = (unsigned long long*)last;
        if (p == end) return last;
        unsigned long long* min_p = p;
        p++;
        while (p < end) {
            if (*p < *min_p) min_p = p;
            p++;
        }
        return min_p;
    }

    void __std_init_once_link_alternate_names_and_abort() {}

    void* my_calloc_dbg(size_t num, size_t size, int blockType, const char* filename, int linenumber) {
        return calloc(num, size);
    }
    void* my_malloc_dbg(size_t size, int blockType, const char* filename, int linenumber) {
        return malloc(size);
    }
    void my_free_dbg(void* userData, int blockType) {
        free(userData);
    }
    void* my_realloc_dbg(void* userData, size_t newSize, int blockType, const char* filename, int linenumber) {
        return realloc(userData, newSize);
    }
    int my_CrtDbgReport(int reportType, const char* filename, int linenumber, const char* moduleName, const char* format, ...) {
        return 0;
    }
    int my_CrtDbgReportW(int reportType, const wchar_t* filename, int linenumber, const wchar_t* moduleName, const wchar_t* format, ...) {
        return 0;
    }

    void my_invalid_parameter(wchar_t const* expression, wchar_t const* function_name, wchar_t const* file_name, unsigned int line_number, uintptr_t reserved) {}

    void* (*__imp__calloc_dbg)(size_t, size_t, int, const char*, int) = my_calloc_dbg;
    void* (*__imp__malloc_dbg)(size_t, int, const char*, int) = my_malloc_dbg;
    void (*__imp__free_dbg)(void*, int) = my_free_dbg;
    void* (*__imp__realloc_dbg)(void*, size_t, int, const char*, int) = my_realloc_dbg;
    int (*__imp__CrtDbgReport)(int, const char*, int, const char*, const char*, ...) = my_CrtDbgReport;
    int (*__imp__CrtDbgReportW)(int, const wchar_t*, int, const wchar_t*, const wchar_t*, ...) = my_CrtDbgReportW;
    void (*__imp__invalid_parameter)(wchar_t const*, wchar_t const*, wchar_t const*, unsigned int, uintptr_t) = my_invalid_parameter;
}
