import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/incidents/domain/incident_report.dart';
import 'package:rangernet/features/incidents/domain/incident_workflow_policy.dart';

void main() {
  group('ranger assignment rules', () {
    test('one-ranger assignment accepts exactly one person', () {
      expect(
        () => IncidentWorkflowPolicy.validateAssignmentSelection(
          IncidentAssignmentKind.ranger,
          1,
        ),
        returnsNormally,
      );
    });

    test('response team accepts two or more people', () {
      expect(
        () => IncidentWorkflowPolicy.validateAssignmentSelection(
          IncidentAssignmentKind.responseTeam,
          2,
        ),
        returnsNormally,
      );
      expect(
        () => IncidentWorkflowPolicy.validateAssignmentSelection(
          IncidentAssignmentKind.responseTeam,
          5,
        ),
        returnsNormally,
      );
    });

    test('rejects zero, too few, or multiple single-ranger selections', () {
      for (final selection in [
        (IncidentAssignmentKind.ranger, 0),
        (IncidentAssignmentKind.ranger, 2),
        (IncidentAssignmentKind.responseTeam, 0),
        (IncidentAssignmentKind.responseTeam, 1),
      ]) {
        expect(
          () => IncidentWorkflowPolicy.validateAssignmentSelection(
            selection.$1,
            selection.$2,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('manager review rules', () {
    test('allows normal review without a note', () {
      expect(
        () => IncidentWorkflowPolicy.validateReview(
          currentStatus: IncidentWorkflowStatus.reported,
          severity: IncidentSeverity.medium,
          note: '',
        ),
        returnsNormally,
      );
    });

    test('critical review requires a meaningful reason', () {
      expect(
        () => IncidentWorkflowPolicy.validateReview(
          currentStatus: IncidentWorkflowStatus.reported,
          severity: IncidentSeverity.critical,
          note: '  ',
        ),
        throwsArgumentError,
      );
      expect(
        () => IncidentWorkflowPolicy.validateReview(
          currentStatus: IncidentWorkflowStatus.reported,
          severity: IncidentSeverity.critical,
          note: 'Threat is active',
        ),
        returnsNormally,
      );
    });

    test('closed incident cannot be reviewed', () {
      expect(
        () => IncidentWorkflowPolicy.validateReview(
          currentStatus: IncidentWorkflowStatus.closed,
          severity: IncidentSeverity.low,
          note: 'Review',
        ),
        throwsStateError,
      );
    });
  });

  group('manager status changes', () {
    test('allows a reasoned follow-up action', () {
      expect(
        () => IncidentWorkflowPolicy.validateManagerTransition(
          currentStatus: IncidentWorkflowStatus.assigned,
          nextStatus: IncidentWorkflowStatus.followUpRequired,
          note: 'Check this block again tomorrow',
        ),
        returnsNormally,
      );
    });

    test(
      'requires a reason for follow-up, monitoring, reject, duplicate, close, and critical',
      () {
        final reasonRequiredStatuses = [
          IncidentWorkflowStatus.followUpRequired,
          IncidentWorkflowStatus.monitoring,
          IncidentWorkflowStatus.duplicate,
          IncidentWorkflowStatus.rejected,
        ];
        for (final status in reasonRequiredStatuses) {
          expect(
            () => IncidentWorkflowPolicy.validateManagerTransition(
              currentStatus: IncidentWorkflowStatus.assigned,
              nextStatus: status,
              note: '  ',
            ),
            throwsArgumentError,
          );
        }
        expect(
          () => IncidentWorkflowPolicy.validateManagerTransition(
            currentStatus: IncidentWorkflowStatus.assigned,
            nextStatus: IncidentWorkflowStatus.underReview,
            note: '',
            severity: IncidentSeverity.critical,
          ),
          throwsArgumentError,
        );
        expect(
          () => IncidentWorkflowPolicy.validateManagerTransition(
            currentStatus: IncidentWorkflowStatus.resolved,
            nextStatus: IncidentWorkflowStatus.closed,
            note: 'Resolution confirmed',
          ),
          returnsNormally,
        );
      },
    );

    test('cannot close before ranger resolution', () {
      expect(
        () => IncidentWorkflowPolicy.validateManagerTransition(
          currentStatus: IncidentWorkflowStatus.assigned,
          nextStatus: IncidentWorkflowStatus.closed,
          note: 'Looks finished',
        ),
        throwsStateError,
      );
    });

    test('closed incidents cannot be changed again', () {
      expect(
        () => IncidentWorkflowPolicy.validateManagerTransition(
          currentStatus: IncidentWorkflowStatus.closed,
          nextStatus: IncidentWorkflowStatus.monitoring,
          note: 'Try again',
        ),
        throwsStateError,
      );
    });

    test('rejects statuses that belong to another workflow actor', () {
      for (final status in [
        IncidentWorkflowStatus.assigned,
        IncidentWorkflowStatus.responseInProgress,
        IncidentWorkflowStatus.resolved,
      ]) {
        expect(
          () => IncidentWorkflowPolicy.validateManagerTransition(
            currentStatus: IncidentWorkflowStatus.reported,
            nextStatus: status,
            note: 'Change it',
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('responder update rules', () {
    test('accepts the shortest valid trimmed note for both valid statuses', () {
      for (final status in [
        IncidentWorkflowStatus.responseInProgress,
        IncidentWorkflowStatus.resolved,
      ]) {
        expect(
          () => IncidentWorkflowPolicy.validateResponderUpdate(
            note: ' 12345 ',
            status: status,
          ),
          returnsNormally,
        );
      }
    });

    test('rejects blank and too-short notes', () {
      for (final note in ['', '    ', 'four']) {
        expect(
          () => IncidentWorkflowPolicy.validateResponderUpdate(
            note: note,
            status: IncidentWorkflowStatus.responseInProgress,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects manager-only and non-response statuses', () {
      expect(
        () => IncidentWorkflowPolicy.validateResponderUpdate(
          note: 'Found and removed it',
          status: IncidentWorkflowStatus.closed,
        ),
        throwsArgumentError,
      );
    });
  });
}
