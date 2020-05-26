import 'package:actionlib_msgs/msgs.dart';
import 'package:dartx/dartx.dart';
import '../dartros.dart';
import 'actions/goal_id_generator.dart';
import 'node_handle.dart';
import 'utils/msg_utils.dart';

abstract class ActionLibClient<G extends RosMessage<G>, F extends RosMessage<F>,
    R extends RosMessage<R>> {
  final G goalClass;
  final F feedbackClass;
  final R resultClass;
  Publisher<G> _goalPub;
  Publisher<GoalID> _cancelPub;
  Subscriber<GoalStatusArray> _statusSub;
  Subscriber<F> _feedbackSub;
  Subscriber<R> _resultSub;
  NodeHandle node;
  final String actionServer;
  bool hasStatus = false;
  ActionLibClient(this.actionServer, this.node, this.goalClass,
      this.feedbackClass, this.resultClass) {
    _goalPub = node.advertise(actionServer + '/goal', goalClass,
        queueSize: 10, latching: false);
    _cancelPub = node.advertise(actionServer + '/cancel', actionlib_msgs.GoalID,
        queueSize: 10, latching: false);
    _statusSub = node.subscribe(
        actionServer + '/status', actionlib_msgs.GoalStatusArray, _handleStatus,
        queueSize: 1);
    _feedbackSub = node.subscribe(
        actionServer + '/feedback', feedbackClass, handleFeedback,
        queueSize: 1);
    _resultSub = node.subscribe(
        actionServer + '/result', resultClass, handleResult,
        queueSize: 1);
  }
  String get type => goalClass.fullType;
  void cancel(String id, [RosTime stamp]) {
    stamp ??= RosTime.now();
    final cancelGoal = GoalID(stamp: stamp);
    cancelGoal.id = id ?? cancelGoal.id;
    _cancelPub.publish(cancelGoal);
  }

  void sendGoal(G goal) {
    _goalPub.publish(goal);
  }

  void _handleStatus(GoalStatusArray status) {
    hasStatus = true;
    handleStatus(status);
  }

  void handleStatus(GoalStatusArray status);
  void handleResult(R result);
  void handleFeedback(F feedback);

  Future<void> shutdown() async {
    return await Future.wait([
      _goalPub.shutdown(),
      _cancelPub.shutdown(),
      _statusSub.shutdown(),
      _feedbackSub.shutdown(),
      _resultSub.shutdown()
    ]);
  }

  bool get isServerConnected {
    return hasStatus &&
        _goalPub.numSubscribers > 0 &&
        _cancelPub.numSubscribers > 0 &&
        _statusSub.numPublishers > 0 &&
        _feedbackSub.numPublishers > 0 &&
        _resultSub.numPublishers > 0;
  }

  Future<bool> waitForActionServerToStart([int timeoutMs = 0]) async {
    if (isServerConnected) {
      return Future.value(true);
    } else {
      return await _waitForActionServerToStart(timeoutMs, DateTime.now());
    }
  }

  Future<bool> _waitForActionServerToStart(
      int timeoutMs, DateTime start) async {
    while (timeoutMs > 0 && start + timeoutMs.milliseconds > DateTime.now()) {
      await Future.delayed(100.milliseconds);
      if (isServerConnected) {
        return true;
      }
    }
    return false;
  }

  String generateGoalID([RosTime now]) {
    GoalIDGenerator.generateGoalID(now);
  }
}
