project('mir-runtime', 'd', version : '0.0.0', license: 'BSL-1.0')

mir_runtime_dir = include_directories('source/')

mir_runtime_src = [
    'source/mir/appender.d',
    'source/mir/exception.d',
    'source/mir/format_impl.d',
    'source/mir/format.d',
]

mir_runtime_lib = library(meson.project_name(),
    mir_runtime_src,
    include_directories: mir_runtime_dir,
    install: true,
    version: meson.project_version(),
)

mir_runtime_dep = declare_dependency(
    link_with: [mir_runtime_lib],
    include_directories: mir_runtime_dir,
)

mir_runtime_test_exe = executable(meson.project_name() + '-test',
    mir_runtime_src,
    include_directories: mir_runtime_dir,
    d_unittest: true,
    d_module_versions: ['mir_test'],
    link_args: '-main',
)

install_subdir('source/',
    strip_directory : true,
    install_dir: 'include/d/' + meson.project_name(),
)

import('pkgconfig').generate(
    name: meson.project_name(),
    description: 'Mir runtime - Base software building blocks and conventions.',
    subdirs: 'd/' + meson.project_name(),
    libraries: [mir_runtime_lib],
    version: meson.project_version(),
)

test(meson.project_name() + '-test', mir_runtime_test_exe)
