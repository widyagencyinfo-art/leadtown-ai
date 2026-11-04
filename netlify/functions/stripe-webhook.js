const Stripe = require('stripe');
const { createClient } = require('@supabase/supabase-js');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method not allowed' };
  }

  const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
  const sig = event.headers['stripe-signature'];
  let stripeEvent;

  try {
    stripeEvent = stripe.webhooks.constructEvent(
      event.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature failed:', err.message);
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
  );

  switch (stripeEvent.type) {
    case 'checkout.session.completed': {
      const session = stripeEvent.data.object;
      const { userId, plan } = session.metadata;

      if (userId) {
        await supabase
          .from('profiles')
          .update({
            plan,
            stripe_customer_id: session.customer,
            stripe_subscription_id: session.subscription,
            plan_active: true,
          })
          .eq('id', userId);
      }
      break;
    }

    case 'customer.subscription.updated': {
      const sub = stripeEvent.data.object;
      const active = ['active', 'trialing'].includes(sub.status);

      const { data } = await supabase
        .from('profiles')
        .select('id')
        .eq('stripe_subscription_id', sub.id)
        .single();

      if (data) {
        await supabase
          .from('profiles')
          .update({ plan_active: active })
          .eq('id', data.id);
      }
      break;
    }

    case 'customer.subscription.deleted': {
      const sub = stripeEvent.data.object;

      await supabase
        .from('profiles')
        .update({ plan: 'free', plan_active: false })
        .eq('stripe_subscription_id', sub.id);
      break;
    }
  }

  return { statusCode: 200, body: JSON.stringify({ received: true }) };
};
