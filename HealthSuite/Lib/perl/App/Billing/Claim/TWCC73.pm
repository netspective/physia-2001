##############################################################################
package App::Billing::Claim::TWCC73;
##############################################################################

use strict;

use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type, %params) = @_;

	$params{injuryDescription} = undef;
	$params{medicalCondition} = undef;

	$params{returnToWorkDate} = undef;
	$params{returnToWorkFromDate} = undef;
	$params{returnToWorkToDate} = undef;

	$params{postureRestrictionsStanding} = undef;
	$params{postureRestrictionsStandingOther} = undef;
	$params{postureRestrictionsSitting} = undef;
	$params{postureRestrictionsSittingOther} = undef;
	$params{postureRestrictionsKneeling} = undef;
	$params{postureRestrictionsKneelingOther} = undef;
	$params{postureRestrictionsBending} = undef;
	$params{postureRestrictionsBendingOther} = undef;
	$params{postureRestrictionsPushing} = undef;
	$params{postureRestrictionsPushingOther} = undef;
	$params{postureRestrictionsTwisting} = undef;
	$params{postureRestrictionsTwistingOther} = undef;
	$params{postureRestrictionsOther} = undef;
	$params{postureRestrictionsOtherOther} = undef;
	$params{postureRestrictionsOtherText} = undef;

	$params{specificRestrictions} = undef;
	$params{specificRestrictionsOther} = undef;

	$params{otherRestrictions} = undef;
	$params{motionRestrictionsWalking} = undef;
	$params{motionRestrictionsWalkingOther} = undef;
	$params{motionRestrictionsClimbing} = undef;
	$params{motionRestrictionsClimbingOther} = undef;
	$params{motionRestrictionsGrasping} = undef;
	$params{motionRestrictionsGraspingOther} = undef;
	$params{motionRestrictionsWrist} = undef;
	$params{motionRestrictionsWristOther} = undef;
	$params{motionRestrictionsReaching} = undef;
	$params{motionRestrictionsReachingOther} = undef;
	$params{motionRestrictionsOverhead} = undef;
	$params{motionRestrictionsOverheadOther} = undef;
	$params{motionRestrictionsKeyboard} = undef;
	$params{motionRestrictionsKeyboardOther} = undef;
	$params{motionRestrictionsOther} = undef;
	$params{motionRestrictionsOtherOther} = undef;
	$params{motionRestrictionsOtherText} = undef;

	$params{liftRestrictions} = undef;
	$params{liftRestrictionsHours} = undef;
	$params{liftRestrictionsWeight} = undef;
	$params{liftRestrictionsOther} = undef;

	$params{miscRestrictionsMaxHours} = undef;
	$params{miscRestrictionsSitBreaks} = undef;
	$params{miscRestrictionsSitBreaksPer} = undef;
	$params{miscRestrictionsWearSplint} = undef;
	$params{miscRestrictionsCrutches} = undef;
	$params{miscRestrictionsNoDriving} = undef;
	$params{miscRestrictionsDriveAutoTrans} = undef;
	$params{miscRestrictionsNoWork} = undef;
	$params{miscRestrictionsHoursPerDay} = undef;
	$params{miscRestrictionsTemp} = undef;
	$params{miscRestrictionsHeight} = undef;
	$params{miscRestrictionsMustKeep} = undef;
	$params{miscRestrictionsElevated} = undef;
	$params{miscRestrictionsCleanDry} = undef;
	$params{miscRestrictionsNoSkinContact} = undef;
	$params{miscRestrictionsDressing} = undef;
	$params{miscRestrictionsNoRunning} = undef;

	$params{medicationRestrictionsMustTake} = undef;
	$params{medicationRestrictionsAdvised} = undef;
	$params{medicationRestrictionsDrowsy} = undef;

	$params{workInjuryDiagnosisInfo} = undef;

	$params{followupServiceEvaluationDate} = undef;
	$params{followupServiceEvaluationTime} = undef;
	$params{followupServiceConsultWith} = undef;
	$params{followupServiceConsultDate} = undef;
	$params{followupServiceConsultTime} = undef;
	$params{followupServicePhysMedWeeks} = undef;
	$params{followupServicePhysMedWeeksPer} = undef;
	$params{followupServicePhysMedDate} = undef;
	$params{followupServicePhysMedTime} = undef;
	$params{followupServiceSpecialStudies} = undef;
	$params{followupServiceSpecialStudiesDate} = undef;
	$params{followupServiceSpecialStudiesTime} = undef;
	$params{followupServiceNone} = undef;
	$params{visitType} = undef;
	$params{doctorRole} = undef;

	return bless \%params, $type;
}

sub setInjuryDescription
{
	my ($self, $value) = @_;
	$self->{injuryDescription} = $value;
}

sub getInjuryDescription
{
	my $self = shift;
	return $self->{injuryDescription};
}

sub setMedicalCondition
{
	my ($self, $value) = @_;
	$self->{medicalCondition} = $value;
}

sub getMedicalCondition
{
	my $self = shift;
	return $self->{medicalCondition};
}

sub setReturnToWorkDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{returnToWorkDate} = $value;
}

sub getReturnToWorkDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{returnToWorkDate}) : $self->{returnToWorkDate};
}

sub setReturnToWorkFromDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{returnToWorkFromDate} = $value;
}

sub getReturnToWorkFromDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{returnToWorkFromDate}) : $self->{returnToWorkFromDate};
}

sub setReturnToWorkToDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{returnToWorkToDate} = $value;
}

sub getReturnToWorkToDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{returnToWorkToDate}) : $self->{returnToWorkToDate};
}

sub setPostureRestrictionsStanding
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsStanding} = $value;
}

sub getPostureRestrictionsStanding
{
	my $self = shift;
	return $self->{postureRestrictionsStanding};
}

sub setPostureRestrictionsStandingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsStandingOther} = $value;
}

sub getPostureRestrictionsStandingOther
{
	my $self = shift;
	return $self->{postureRestrictionsStandingOther};
}

sub setPostureRestrictionsSitting
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsSitting} = $value;
}

sub getPostureRestrictionsSitting
{
	my $self = shift;
	return $self->{postureRestrictionsSitting};
}

sub setPostureRestrictionsSittingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsSittingOther} = $value;
}

sub getPostureRestrictionsSittingOther
{
	my $self = shift;
	return $self->{postureRestrictionsSittingOther};
}

sub setPostureRestrictionsKneeling
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsKneeling} = $value;
}

sub getPostureRestrictionsKneeling
{
	my $self = shift;
	return $self->{postureRestrictionsKneeling};
}

sub setPostureRestrictionsKneelingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsKneelingOther} = $value;
}

sub getPostureRestrictionsKneelingOther
{
	my $self = shift;
	return $self->{postureRestrictionsKneelingOther};
}

sub setPostureRestrictionsBending
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsBending} = $value;
}

sub getPostureRestrictionsBending
{
	my $self = shift;
	return $self->{postureRestrictionsBending};
}

sub setPostureRestrictionsBendingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsBendingOther} = $value;
}

sub getPostureRestrictionsBendingOther
{
	my $self = shift;
	return $self->{postureRestrictionsBendingOther};
}

sub setPostureRestrictionsPushing
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsPushing} = $value;
}

sub getPostureRestrictionsPushing
{
	my $self = shift;
	return $self->{postureRestrictionsPushing};
}

sub setPostureRestrictionsPushingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsPushingOther} = $value;
}

sub getPostureRestrictionsPushingOther
{
	my $self = shift;
	return $self->{postureRestrictionsPushingOther};
}

sub setPostureRestrictionsTwisting
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsTwisting} = $value;
}

sub getPostureRestrictionsTwisting
{
	my $self = shift;
	return $self->{postureRestrictionsTwisting};
}

sub setPostureRestrictionsTwistingOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsTwistingOther} = $value;
}

sub getPostureRestrictionsTwistingOther
{
	my $self = shift;
	return $self->{postureRestrictionsTwistingOther};
}

sub setPostureRestrictionsOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsOther} = $value;
}

sub getPostureRestrictionsOther
{
	my $self = shift;
	return $self->{postureRestrictionsOther};
}

sub setPostureRestrictionsOtherOther
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsOtherOther} = $value;
}

sub getPostureRestrictionsOtherOther
{
	my $self = shift;
	return $self->{postureRestrictionsOtherOther};
}

sub setPostureRestrictionsOtherText
{
	my ($self, $value) = @_;
	$self->{postureRestrictionsOtherText} = $value;
}

sub getPostureRestrictionsOtherText
{
	my $self = shift;
	return $self->{postureRestrictionsOtherText};
}

sub setSpecificRestrictions
{
	my ($self, $value) = @_;
	$self->{specificRestrictions} = $value;
}

sub getSpecificRestrictions
{
	my $self = shift;
	return $self->{specificRestrictions};
}

sub setSpecificRestrictionsOther
{
	my ($self, $value) = @_;
	$self->{specificRestrictionsOther} = $value;
}

sub getSpecificRestrictionsOther
{
	my $self = shift;
	return $self->{specificRestrictionsOther};
}

sub setOtherRestrictions
{
	my ($self, $value) = @_;
	$self->{otherRestrictions} = $value;
}

sub getOtherRestrictions
{
	my $self = shift;
	return $self->{otherRestrictions};
}


sub setMotionRestrictionsWalking
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsWalking} = $value;
}

sub getMotionRestrictionsWalking
{
	my $self = shift;
	return $self->{motionRestrictionsWalking};
}

sub setMotionRestrictionsWalkingOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsWalkingOther} = $value;
}

sub getMotionRestrictionsWalkingOther
{
	my $self = shift;
	return $self->{motionRestrictionsWalkingOther};
}

sub setMotionRestrictionsClimbing
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsClimbing} = $value;
}

sub getMotionRestrictionsClimbing
{
	my $self = shift;
	return $self->{motionRestrictionsClimbing};
}

sub setMotionRestrictionsClimbingOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsClimbingOther} = $value;
}

sub getMotionRestrictionsClimbingOther
{
	my $self = shift;
	return $self->{motionRestrictionsClimbingOther};
}

sub setMotionRestrictionsGrasping
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsGrasping} = $value;
}

sub getMotionRestrictionsGrasping
{
	my $self = shift;
	return $self->{motionRestrictionsGrasping};
}

sub setMotionRestrictionsGraspingOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsGraspingOther} = $value;
}

sub getMotionRestrictionsGraspingOther
{
	my $self = shift;
	return $self->{motionRestrictionsGraspingOther};
}

sub setMotionRestrictionsWrist
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsWrist} = $value;
}

sub getMotionRestrictionsWrist
{
	my $self = shift;
	return $self->{motionRestrictionsWrist};
}

sub setMotionRestrictionsWristOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsWristOther} = $value;
}

sub getMotionRestrictionsWristOther
{
	my $self = shift;
	return $self->{motionRestrictionsWristOther};
}

sub setMotionRestrictionsReaching
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsReaching} = $value;
}

sub getMotionRestrictionsReaching
{
	my $self = shift;
	return $self->{motionRestrictionsReaching};
}

sub setMotionRestrictionsReachingOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsReachingOther} = $value;
}

sub getMotionRestrictionsReachingOther
{
	my $self = shift;
	return $self->{motionRestrictionsReachingOther};
}

sub setMotionRestrictionsOverhead
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsOverhead} = $value;
}

sub getMotionRestrictionsOverhead
{
	my $self = shift;
	return $self->{motionRestrictionsOverhead};
}

sub setMotionRestrictionsOverheadOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsOverheadOther} = $value;
}

sub getMotionRestrictionsOverheadOther
{
	my $self = shift;
	return $self->{motionRestrictionsOverheadOther};
}


sub setMotionRestrictionsKeyboard
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsKeyboard} = $value;
}

sub getMotionRestrictionsKeyboard
{
	my $self = shift;
	return $self->{motionRestrictionsKeyboard};
}

sub setMotionRestrictionsKeyboardOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsKeyboardOther} = $value;
}

sub getMotionRestrictionsKeyboardOther
{
	my $self = shift;
	return $self->{motionRestrictionsKeyboardOther};
}

sub setMotionRestrictionsOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsOther} = $value;
}

sub getMotionRestrictionsOther
{
	my $self = shift;
	return $self->{motionRestrictionsOther};
}

sub setMotionRestrictionsOtherOther
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsOtherOther} = $value;
}

sub getMotionRestrictionsOtherOther
{
	my $self = shift;
	return $self->{motionRestrictionsOtherOther};
}

sub setMotionRestrictionsOtherText
{
	my ($self, $value) = @_;
	$self->{motionRestrictionsOtherText} = $value;
}

sub getMotionRestrictionsOtherText
{
	my $self = shift;
	return $self->{motionRestrictionsOtherText};
}

sub setLiftRestrictions
{
	my ($self, $value) = @_;
	$self->{liftRestrictions} = $value;
}

sub getLiftRestrictions
{
	my $self = shift;
	return $self->{liftRestrictions};
}

sub setLiftRestrictionsHours
{
	my ($self, $value) = @_;
	$self->{liftRestrictionsHours} = $value;
}

sub getLiftRestrictionsHours
{
	my $self = shift;
	return $self->{liftRestrictionsHours};
}

sub setLiftRestrictionsWeight
{
	my ($self, $value) = @_;
	$self->{liftRestrictionsWeight} = $value;
}

sub getLiftRestrictionsWeight
{
	my $self = shift;
	return $self->{liftRestrictionsWeight};
}

sub setLiftRestrictionsOther
{
	my ($self, $value) = @_;
	$self->{liftRestrictionsOther} = $value;
}

sub getLiftRestrictionsOther
{
	my $self = shift;
	return $self->{liftRestrictionsOther};
}

sub setMiscRestrictionsMaxHours
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsMaxHours} = $value;
}

sub getMiscRestrictionsMaxHours
{
	my $self = shift;
	return $self->{miscRestrictionsMaxHours};
}

sub setMiscRestrictionsSitBreaks
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsSitBreaks} = $value;
}

sub getMiscRestrictionsSitBreaks
{
	my $self = shift;
	return $self->{miscRestrictionsSitBreaks};
}

sub setMiscRestrictionsSitBreaksPer
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsSitBreaksPer} = $value;
}

sub getMiscRestrictionsSitBreaksPer
{
	my $self = shift;
	return $self->{miscRestrictionsSitBreaksPer};
}

sub setMiscRestrictionsWearSplint
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsWearSplint} = $value;
}

sub getMiscRestrictionsWearSplint
{
	my $self = shift;
	return $self->{miscRestrictionsWearSplint};
}

sub setMiscRestrictionsCrutches
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsCrutches} = $value;
}

sub getMiscRestrictionsCrutches
{
	my $self = shift;
	return $self->{miscRestrictionsCrutches};
}

sub setMiscRestrictionsNoDriving
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsNoDriving} = $value;
}

sub getMiscRestrictionsNoDriving
{
	my $self = shift;
	return $self->{miscRestrictionsNoDriving};
}

sub setMiscRestrictionsDriveAutoTrans
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsDriveAutoTrans} = $value;
}

sub getMiscRestrictionsDriveAutoTrans
{
	my $self = shift;
	return $self->{miscRestrictionsDriveAutoTrans};
}

sub setMiscRestrictionsNoWork
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsNoWork} = $value;
}

sub getMiscRestrictionsNoWork
{
	my $self = shift;
	return $self->{miscRestrictionsNoWork};
}

sub setMiscRestrictionsHoursPerDay
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsHoursPerDay} = $value;
}

sub getMiscRestrictionsHoursPerDay
{
	my $self = shift;
	return $self->{miscRestrictionsHoursPerDay};
}

sub setMiscRestrictionsTemp
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsTemp} = $value;
}

sub getMiscRestrictionsTemp
{
	my $self = shift;
	return $self->{miscRestrictionsTemp};
}

sub setMiscRestrictionsHeight
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsHeight} = $value;
}

sub getMiscRestrictionsHeight
{
	my $self = shift;
	return $self->{miscRestrictionsHeight};
}

sub setMiscRestrictionsMustKeep
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsMustKeep} = $value;
}

sub getMiscRestrictionsMustKeep
{
	my $self = shift;
	return $self->{miscRestrictionsMustKeep};
}

sub setMiscRestrictionsElevated
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsElevated} = $value;
}

sub getMiscRestrictionsElevated
{
	my $self = shift;
	return $self->{miscRestrictionsElevated};
}

sub setMiscRestrictionsCleanDry
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsCleanDry} = $value;
}

sub getMiscRestrictionsCleanDry
{
	my $self = shift;
	return $self->{miscRestrictionsCleanDry};
}

sub setMiscRestrictionsNoSkinContact
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsNoSkinContact} = $value;
}

sub getMiscRestrictionsNoSkinContact
{
	my $self = shift;
	return $self->{miscRestrictionsNoSkinContact};
}

sub setMiscRestrictionsDressing
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsDressing} = $value;
}

sub getMiscRestrictionsDressing
{
	my $self = shift;
	return $self->{miscRestrictionsDressing};
}

sub setMiscRestrictionsNoRunning
{
	my ($self, $value) = @_;
	$self->{miscRestrictionsNoRunning} = $value;
}

sub getMiscRestrictionsNoRunning
{
	my $self = shift;
	return $self->{miscRestrictionsNoRunning};
}

sub setMedicationRestrictionsMustTake
{
	my ($self, $value) = @_;
	$self->{medicationRestrictionsMustTake} = $value;
}

sub getMedicationRestrictionsMustTake
{
	my $self = shift;
	return $self->{medicationRestrictionsMustTake};
}

sub setMedicationRestrictionsAdvised
{
	my ($self, $value) = @_;
	$self->{medicationRestrictionsAdvised} = $value;
}

sub getMedicationRestrictionsAdvised
{
	my $self = shift;
	return $self->{medicationRestrictionsAdvised};
}

sub setMedicationRestrictionsDrowsy
{
	my ($self, $value) = @_;
	$self->{medicationRestrictionsDrowsy} = $value;
}

sub getMedicationRestrictionsDrowsy
{
	my $self = shift;
	return $self->{medicationRestrictionsDrowsy};
}

sub setWorkInjuryDiagnosisInfo
{
	my ($self, $value) = @_;
	$self->{workInjuryDiagnosisInfo} = $value;
}

sub getWorkInjuryDiagnosisInfo
{
	my $self = shift;
	return $self->{workInjuryDiagnosisInfo};
}

sub setFollowupServiceEvaluationDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{followupServiceEvaluationDate} = $value;
}

sub getFollowupServiceEvaluationDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{followupServiceEvaluationDate}) : $self->{followupServiceEvaluationDate};
}

sub setFollowupServiceEvaluationTime
{
	my ($self, $value) = @_;
	$self->{followupServiceEvaluationTime} = $value;
}

sub getFollowupServiceEvaluationTime
{
	my $self = shift;
	return $self->{followupServiceEvaluationTime};
}

sub setFollowupServiceConsultWith
{
	my ($self, $value) = @_;
	$self->{followupServiceConsultWith} = $value;
}

sub getFollowupServiceConsultWith
{
	my $self = shift;
	return $self->{followupServiceConsultWith};
}

sub setFollowupServiceConsultDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{followupServiceConsultDate} = $value;
}

sub getFollowupServiceConsultDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{followupServiceConsultDate}) : $self->{followupServiceConsultDate};
}

sub setFollowupServiceConsultTime
{
	my ($self, $value) = @_;
	$self->{followupServiceConsultTime} = $value;
}

sub getFollowupServiceConsultTime
{
	my $self = shift;
	return $self->{followupServiceConsultTime};
}

sub setFollowupServicePhysMedWeeks
{
	my ($self, $value) = @_;
	$self->{followupServicePhysMedWeeks} = $value;
}

sub getFollowupServicePhysMedWeeks
{
	my $self = shift;
	return $self->{followupServicePhysMedWeeks};
}

sub setFollowupServicePhysMedWeeksPer
{
	my ($self, $value) = @_;
	$self->{followupServicePhysMedWeeksPer} = $value;
}

sub getFollowupServicePhysMedWeeksPer
{
	my $self = shift;
	return $self->{followupServicePhysMedWeeksPer};
}

sub setFollowupServicePhysMedDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{followupServicePhysMedDate} = $value;
}

sub getFollowupServicePhysMedDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{followupServicePhysMedDate}) : $self->{followupServicePhysMedDate};
}

sub setFollowupServicePhysMedTime
{
	my ($self, $value) = @_;
	$self->{followupServicePhysMedTime} = $value;
}

sub getFollowupServicePhysMedTime
{
	my $self = shift;
	return $self->{followupServicePhysMedTime};
}

sub setFollowupServiceSpecialStudies
{
	my ($self, $value) = @_;
	$self->{followupServiceSpecialStudies} = $value;
}

sub getFollowupServiceSpecialStudies
{
	my $self = shift;
	return $self->{followupServiceSpecialStudies};
}

sub setFollowupServiceSpecialStudiesDate
{
	my ($self, $value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{followupServiceSpecialStudiesDate} = $value;
}

sub getFollowupServiceSpecialStudiesDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? 	$self->convertDateToMMDDYYYYFromCCYYMMDD($self->{followupServiceSpecialStudiesDate}) : $self->{followupServiceSpecialStudiesDate};
}

sub setFollowupServiceSpecialStudiesTime
{
	my ($self, $value) = @_;
	$self->{followupServiceSpecialStudiesTime} = $value;
}

sub getFollowupServiceSpecialStudiesTime
{
	my $self = shift;
	return $self->{followupServiceSpecialStudiesTime};
}

sub setFollowupServiceNone
{
	my ($self, $value) = @_;
	$self->{followupServiceNone} = $value;
}

sub getFollowupServiceNone
{
	my $self = shift;
	return $self->{followupServiceNone};
}

sub setVisitType
{
	my ($self, $value) = @_;
	$self->{visitType} = $value;
}

sub getVisitType
{
	my $self = shift;
	return $self->{visitType};
}

sub setDoctorRole
{
	my ($self, $value) = @_;
	$self->{doctorRole} = $value;
}

sub getDoctorRole
{
	my $self = shift;
	return $self->{doctorRole};
}

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence =
	{
		JAN => '01', FEB => '02', MAR => '03', APR => '04',
		MAY => '05', JUN => '06', JUL => '07', AUG => '08',
		SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
	};
	$date =~ s/-//g;
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
}

sub convertDateToMMDDYYYYFromCCYYMMDD
{
	my ($self, $date) = @_;
	if ($date ne "")
	{
		return substr($date,4,2) . '/' . substr($date,6,2) . '/' . substr($date,0,4) ;
	}
	else
	{
		return "";
	}
}

1;
