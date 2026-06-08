import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/community/community_home.dart';
import '../widgets/community/community_detail.dart';
import '../widgets/community/post_detail_view.dart';
import '../providers/community_provider.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.read<CommunityProvider>();
    return CommunityHome(
      onNavigateCommunity: (communityId) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<CommunityProvider>.value(
              value: communityProvider,
              child: CommunityDetail(
                communityId: communityId,
                onBack: () => Navigator.of(context).pop(),
                onNavigatePost: (postId) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChangeNotifierProvider<CommunityProvider>.value(
                        value: communityProvider,
                        child: PostDetailView(
                          postId: postId,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
