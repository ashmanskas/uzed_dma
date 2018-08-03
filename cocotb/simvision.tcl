puts {This is simvision.tcl}
preferences set default-time-units ns

if {[catch {window new WatchList -name "Design Browser 1"
    -geometry 700x500+10+400}] != ""} {
    window geometry "Design Browser 1" 700x500+10+400
}

console set -windowname Console
window geometry Console 700x300+10+50

if {1} {
  if {[catch {window new WaveWindow -name "Waveform 1"
     -geometry 1800x1100+0+0}] != ""} {
     window geometry "Waveform 1" 1800x1100+0+0
  }
} {
  if {[catch {window new WaveWindow -name "Waveform 1"
     -geometry 1300x800+0+0}] != ""} {
     window geometry "Waveform 1" 1300x800+0+0
  }
}
window target "Waveform 1" on
# waveform using {Waveform 1}
waveform sidebar visibility partial
waveform set \
    -primarycursor TimeA \
    -signalnames name \
    -signalwidth 200 \
    -units ns \
    -valuewidth 50
waveform baseline set -time 0


# ===
# ===

waveform xview limits 0 2000000ns

window iconify "Design Browser 1"

# ===
source waves.tcl

preferences get key-bindings
preferences set console-output-limited 0
preferences set prompt-exit 0
preferences set marching-waveform 0
preferences set initial-zoom-out-full 1
preferences set waveform-height 10
preferences set waveform-space 1

preferences set cursorctl-dont-show-sync-warning 1
preferences set toolbar-CursorControl-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-sendToIndago-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-TimeSearch-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-NavSignalList-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-txe_waveform_taggle-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-Standard-WaveWindow {
  usual
  shown 0
}
preferences set toolbar-Windows-WaveWindow {
  usual
  shown 0
}


# waveform delta get
# simcontrol run
# cursor get -using TimeA -time
# input <file>
# source <file>
# marker new -time 13000ns
# waveform xview zoom -outfull

waveform set -units ns

console tab select SimVision
console submit -using simulator -wait yes run
input foobar.tcl
cursor new -time 10000ns


