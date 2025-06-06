load("@com_github_datadog_rules_oci//oci:debug_flag.bzl", "DebugInfo")
load("@com_github_datadog_rules_oci//oci:providers.bzl", "OCIDescriptor", "OCILayout", "OCIReferenceInfo")

def _oci_push_impl(ctx):
    toolchain = ctx.toolchains["@com_github_datadog_rules_oci//oci:toolchain"]

    layout = ctx.attr.manifest[OCILayout]

    ref = "{registry}/{repository}".format(
        registry = ctx.attr.registry,
        repository = ctx.attr.repository,
    )

    tag = ctx.expand_make_variables("tag", ctx.attr.tag, {})

    digest_file = ctx.actions.declare_file("{name}.digest".format(name = ctx.label.name))
    ctx.actions.run(
        executable = toolchain.sdk.ocitool,
        arguments = [
            "digest",
            "--desc={desc}".format(desc = ctx.attr.manifest[OCIDescriptor].descriptor_file.path),
            "--out={out}".format(out = digest_file.path),
        ],
        inputs = [
            ctx.attr.manifest[OCIDescriptor].descriptor_file,
        ],
        outputs = [
            digest_file,
        ],
    )

    headers = ""
    for k, v in ctx.attr.headers.items():
        headers = headers + " --headers={}={}".format(k, v)

    xheaders = ""
    for k, v in ctx.attr.x_meta_headers.items():
        xheaders = xheaders + " --x_meta_headers={}={}".format(k, v)

    ctx.actions.write(
        content = """#!/usr/bin/env bash
        set -euo pipefail
        {tool}  \\
        --layout {layout} \\
        --debug={debug} \\
        push \\
        --layout-relative {root} \\
        --desc {desc} \\
        --target-ref {ref} \\
        --parent-tag \"{tag}\" \\
        --mount {mount} \\
        {headers} \\
        {xheaders} \\

        export OCI_REFERENCE={ref}@$(cat {digest})
        {post_scripts}
        """.format(
            root = ctx.bin_dir.path,
            tool = toolchain.sdk.ocitool.short_path,
            layout = layout.blob_index.short_path,
            desc = ctx.attr.manifest[OCIDescriptor].descriptor_file.short_path,
            ref = ref,
            tag = tag,
            debug = str(ctx.attr.debug),
            headers = headers,
            xheaders = xheaders,
            post_scripts = "\n".join(["./" + hook.short_path for hook in toolchain.post_push_hooks]),
            digest = digest_file.short_path,
            mount = "true" if ctx.attr.mount else "false",
        ),
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = layout.files.to_list() +
                        [toolchain.sdk.ocitool, ctx.attr.manifest[OCIDescriptor].descriptor_file, layout.blob_index, digest_file] + toolchain.post_push_hooks,
            ),
        ),
        OCIReferenceInfo(
            registry = ctx.attr.registry,
            repository = ctx.attr.repository,
            digest = digest_file,
        ),
    ]

oci_push = rule(
    doc = """
        Pushes a manifest or a list of manifests to an OCI registry.
    """,
    implementation = _oci_push_impl,
    executable = True,
    attrs = {
        "manifest": attr.label(
            doc = """
                A manifest to push to a registry. If an OCILayout index, then
                push all artifacts with a 'org.opencontainers.image.ref.name'
                annotation.
            """,
            providers = [OCILayout],
        ),
        "registry": attr.string(
            doc = """
                A registry host to push to, if not present consult the toolchain.
            """,
        ),
        "repository": attr.string(
            doc = """
                A repository to push to, if not present consult the toolchain.
            """,
        ),
        "tag": attr.string(
            doc = """
                (optional) A tag to include in the target reference. This will not be included on child images."
            """,
        ),
        "headers": attr.string_dict(
            doc = """
                (optional) A list of key/values to to be sent to the registry as headers.
            """,
        ),
        "x_meta_headers": attr.string_dict(
            doc = """
                (optional) A list of key/values to to be sent to the registry as headers with an X-Meta- prefix.
            """,
        ),
        "mount": attr.bool(
            doc = """
            (optional) Whether to mount existing image or mount all of layers. If not specified, the default is
            False.
            """,
            default = False,
        ),
        "debug": attr.bool(
            doc = """
                (optional) If true, the tool will print debug information.
            """,
            default = False,
        ),
    },
    provides = [
        OCIReferenceInfo,
    ],
    toolchains = ["@com_github_datadog_rules_oci//oci:toolchain"],
)
