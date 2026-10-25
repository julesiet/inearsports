extends Node

signal phase_changed(phase: int)

enum Phase { WAITING, SERVING, RALLY, POINT_AWARDED, FINISHED }

var phase: Phase = Phase.WAITING

const ALLOWED_TRANSITIONS := {
	Phase.WAITING: [Phase.SERVING],
	Phase.SERVING: [Phase.RALLY],
	Phase.RALLY: [Phase.POINT_AWARDED],
	Phase.POINT_AWARDED: [Phase.SERVING, Phase.FINISHED],
	Phase.FINISHED: [],
}


func transition_to(next_phase: Phase) -> bool:
	if not ALLOWED_TRANSITIONS.get(phase, []).has(next_phase):
		print("Rejected match transition: ", Phase.keys()[phase],
			" -> ", Phase.keys()[next_phase])
		return false

	phase = next_phase
	print("Match phase: ", Phase.keys()[phase])
	phase_changed.emit(phase)
	return true
