/// The square of a picture to keep as an avatar, in the picture's own pixels.
final class ChatAvatarCrop {
  const ChatAvatarCrop({
    required this.left,
    required this.top,
    required this.side,
  });

  final double left;
  final double top;
  final double side;

  @override
  bool operator ==(Object other) =>
      other is ChatAvatarCrop &&
      other.left == left &&
      other.top == top &&
      other.side == side;

  @override
  int get hashCode => Object.hash(left, top, side);
}
