package com.vivamatrimony.viva_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterShellArgs

class MainActivity : FlutterActivity() {

    /**
     * Permanently disable Impeller (Vulkan) on Android.
     *
     * Flutter 3.27+ removed the AndroidManifest meta-data key for this flag.
     * The only reliable way to disable it for all launch modes (icon tap,
     * `flutter run`, release APK) is to inject --enable-impeller=false via
     * FlutterShellArgs at the Activity level.
     *
     * Background: Qualcomm Adreno gralloc on MIUI fails to allocate HDR pixel
     * formats (0x38 / 0x3b) that Impeller's Vulkan backend probes on every
     * onResume, leaving a black canvas after any surface re-composite
     * (dialog dismiss, route transition, screen lock/unlock).
     */
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        args.add("--enable-impeller=false")
        return args
    }
}
